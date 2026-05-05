#!/bin/bash

# 取得腳本所在的目錄 (即專案根目錄)
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"

# 解析 --target 參數
TARGET="cursor"
if [[ "${1:-}" == "--target" ]]; then
    if [[ -z "${2:-}" ]]; then
        echo "⚠️ 錯誤: --target 需要引數 (cursor, antigravity 或 gemini)"
        exit 1
    fi
    TARGET="$2"
    shift 2
fi

# 檢查目標專案路徑
if [ -z "$1" ]; then
    echo "⚠️ 請提供目標專案路徑！"
    echo "用法: $0 [--target cursor|antigravity|gemini] <target_project_path> [lang1] [lang2] ..."
    echo "範例: $0 --target gemini ~/Workspace/my-project typescript python"
    echo "預設 target 為 cursor"
    exit 1
fi

if [[ "$TARGET" != "cursor" && "$TARGET" != "antigravity" && "$TARGET" != "gemini" ]]; then
    echo "❌ 錯誤: 未知的 target '$TARGET'，必須是 'cursor'、'antigravity' 或 'gemini'。"
    exit 1
fi

TARGET_DIR="$1"
shift  # 剩下的全部當作語言陣列
LANGS=("$@")

# 檢查目標目錄是否存在
if [ ! -d "$TARGET_DIR" ]; then
    echo "❌ 錯誤: 目標目錄 '$TARGET_DIR' 不存在！"
    exit 1
fi

TARGET_PROJECT="$(cd "$TARGET_DIR" && pwd)"

# 根據 target 決定路徑配置
if [[ "$TARGET" == "cursor" ]]; then
    DEST_BASE="$TARGET_PROJECT/.cursor"
    SRC_RULES="$SRC_DIR/.cursor/rules"
    DEST_RULES="$DEST_BASE/rules"
    SRC_AGENTS="$SRC_DIR/agents"
    DEST_AGENTS="$DEST_BASE/agents"
    # Cursor 模式下：先將根目錄 ./skills 佈署進目標，再將 ./.cursor/skills 佈署進目標，
    # 若同名衝突，後連結的 ./.cursor/skills 會覆蓋（符合同名以 cursor 為主）。
    SRC_SKILLS_COMMON="$SRC_DIR/skills"
    SRC_SKILLS="$SRC_DIR/.cursor/skills"
    DEST_SKILLS="$DEST_BASE/skills"
    SRC_CMDS="$SRC_DIR/.cursor/commands"
    DEST_CMDS="$DEST_BASE/commands"
    SRC_HOOKS_JSON="$SRC_DIR/.cursor/hooks.json"
    SRC_HOOKS_DIR="$SRC_DIR/.cursor/hooks"
elif [[ "$TARGET" == "gemini" ]]; then
    # Gemini CLI: 習慣放在 .gemini 目錄
    DEST_BASE="$TARGET_PROJECT/.gemini"
    SRC_RULES="$SRC_DIR/rules"
    DEST_RULES="$DEST_BASE/rules"
    SRC_SKILLS="$SRC_DIR/skills"
    DEST_SKILLS="$DEST_BASE/skills"
    SRC_CMDS="$SRC_DIR/commands"
    DEST_CMDS="$DEST_BASE/commands"
else
    # Antigravity: rules/skills 放 .agents，workflows 僅來源於 commands
    DEST_BASE="$TARGET_PROJECT/.agents"
    SRC_RULES="$SRC_DIR/rules"
    DEST_RULES="$DEST_BASE/rules"
    SRC_SKILLS="$SRC_DIR/skills"
    DEST_SKILLS="$DEST_BASE/skills"
    DEST_WORKFLOWS="$DEST_BASE/workflows"
    SRC_CMDS="$SRC_DIR/commands"
    DEST_CMDS="$DEST_WORKFLOWS"
fi

echo "🔧 正在將 $TARGET 設定 (Files) 佈署至 $DEST_BASE..."

# 顯示目前啟用的語言設定
if [ ${#LANGS[@]} -gt 0 ]; then
    echo "📄 指定載入語言專屬檔案: ${LANGS[*]}"
else
    echo "📄 未指定語言，僅載入通用 (Common) 設定。"
fi
echo "----------------------------------------------------"

mkdir -p "$DEST_BASE"

# 定義建立單筆複製的函式
copy_item() {
    local src_file="$1"
    local dest_dir="$2"
    local filename="${3:-$(basename "$src_file")}"
    local dest_path="$dest_dir/$filename"

    mkdir -p "$dest_dir"

    if [ -e "$dest_path" ]; then
        local backup="${dest_path}_backup_$(date +%Y%m%d_%H%M%S)"
        echo "  📦 備份現有檔案: $filename -> ./${filename}_backup_..."
        mv "$dest_path" "$backup"
    fi
    cp -rf "$src_file" "$dest_path"
    echo "  📄 $filename"
}

# 定義按語言過濾後進行複製的核心函式
filter_and_copy() {
    local category="$1"
    local src_dir="$2"
    local dest_dir="$3"
    local rename_md_to_mdc="${4:-false}"

    if [ ! -d "$src_dir" ]; then
        return
    fi

    echo "📂 處理 [$category] ..."
    mkdir -p "$dest_dir"

    # 定義語言關鍵字。不論是檔案前綴 (例如 golang-testing.md) 或是資料夾名稱 (例如 golang/) 都適用
    local known_langs=("golang" "go" "typescript" "ts" "python" "django" "java" "springboot" "jpa" "cpp" "rust" "csharp" "php" "perl" "android" "kotlin" "swift" "swiftui")

    local copied_count=0

    for src_item in "$src_dir"/*; do
        if [ ! -e "$src_item" ]; then continue; fi
        local basename=$(basename "$src_item")
        
        local should_copy=true
        
        # 判斷是否為語言專屬項目
        for klang in "${known_langs[@]}"; do
            if [[ "$basename" == "$klang-"* ]] || [[ "$basename" == "$klang" ]]; then
                should_copy=false 
                
                for u_lang in "${LANGS[@]}"; do
                    if [[ "$klang" == "$u_lang" ]] || [[ "$klang" == "$u_lang-"* ]]; then
                        should_copy=true
                        break
                    fi
                    
                    # 處理框架語意的擴大相容
                    if [[ "$u_lang" == "python" ]] && [[ "$klang" == "django" ]]; then should_copy=true; break; fi
                    if [[ "$u_lang" == "java" ]] && [[ "$klang" == "springboot" || "$klang" == "jpa" ]]; then should_copy=true; break; fi
                    if [[ "$u_lang" == "go" ]] && [[ "$klang" == "golang" ]]; then should_copy=true; break; fi
                    if [[ "$u_lang" == "golang" ]] && [[ "$klang" == "go" ]]; then should_copy=true; break; fi
                    if [[ "$u_lang" == "ts" ]] && [[ "$klang" == "typescript" ]]; then should_copy=true; break; fi
                    if [[ "$u_lang" == "typescript" ]] && [[ "$klang" == "ts" ]]; then should_copy=true; break; fi
                done
                break 
            fi
        done

        if $should_copy; then
            local target_name="$basename"
            if [[ "$rename_md_to_mdc" == "true" ]] && [[ -f "$src_item" ]] && [[ "$basename" == *.md ]]; then
                target_name="${basename%.md}.mdc"
            fi

            copy_item "$src_item" "$dest_dir" "$target_name"
            ((copied_count++))
        fi
    done

    echo "  ✅ 完成 [$category] 複製 ($copied_count 項)"
    echo ""
}

if [[ "$TARGET" == "cursor" ]]; then
    filter_and_copy "Rules"               "$SRC_RULES"  "$DEST_RULES" true
    filter_and_copy "Agents"              "$SRC_AGENTS" "$DEST_AGENTS"
    filter_and_copy "Skills (Common)"   "$SRC_SKILLS_COMMON" "$DEST_SKILLS"
    filter_and_copy "Skills"              "$SRC_SKILLS" "$DEST_SKILLS"
    filter_and_copy "Commands/Workflows"  "$SRC_CMDS"   "$DEST_CMDS"
    hooks_json_ok=false
    hooks_dir_ok=false
    [[ -f "$SRC_HOOKS_JSON" ]] && hooks_json_ok=true
    [[ -d "$SRC_HOOKS_DIR" ]] && hooks_dir_ok=true
    if $hooks_json_ok && $hooks_dir_ok; then
        echo "📂 處理 [Hooks] ..."
        copy_item "$SRC_HOOKS_JSON" "$DEST_BASE" "hooks.json"
        copy_item "$SRC_HOOKS_DIR" "$DEST_BASE" "hooks"
        echo "  ✅ 完成 [Hooks] 複製 (2 項)"
        echo ""
    elif $hooks_json_ok || $hooks_dir_ok; then
        echo "❌ 錯誤: Cursor Hooks 必須同時具備下列兩項（缺一不可）："
        $hooks_json_ok || echo "     缺少: $SRC_HOOKS_JSON"
        $hooks_dir_ok || echo "     缺少: $SRC_HOOKS_DIR"
        exit 1
    elif [[ "$TARGET" == "gemini" ]]; then
        filter_and_copy "Rules"   "$SRC_RULES"   "$DEST_RULES"
        filter_and_copy "Skills"  "$SRC_SKILLS"  "$DEST_SKILLS"
        filter_and_copy "Commands" "$SRC_CMDS"   "$DEST_CMDS"
    else
        filter_and_copy "Rules"   "$SRC_RULES"   "$DEST_RULES"
        filter_and_copy "Skills"  "$SRC_SKILLS"  "$DEST_SKILLS"
        filter_and_copy "Commands/Workflows" "$SRC_CMDS" "$DEST_CMDS"
    fi
else
    filter_and_copy "Rules"   "$SRC_RULES"   "$DEST_RULES"
    filter_and_copy "Skills"  "$SRC_SKILLS"  "$DEST_SKILLS"
    filter_and_copy "Commands/Workflows" "$SRC_CMDS" "$DEST_CMDS"
fi

echo "----------------------------------------------------"
echo "🎉 $TARGET 全數設定完成！"
