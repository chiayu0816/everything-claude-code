#!/bin/bash

# 取得腳本所在的目錄 (即專案根目錄)
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"

# 解析 --target 參數
TARGET="cursor"
if [[ "${1:-}" == "--target" ]]; then
    if [[ -z "${2:-}" ]]; then
        echo "⚠️ 錯誤: --target 需要引數 (cursor 或 antigravity)"
        exit 1
    fi
    TARGET="$2"
    shift 2
fi

# 檢查目標專案路徑
if [ -z "$1" ]; then
    echo "⚠️ 請提供目標專案路徑！"
    echo "用法: $0 [--target cursor|antigravity] <target_project_path> [lang1] [lang2] ..."
    echo "範例: $0 --target antigravity ~/Workspace/my-project typescript python"
    echo "預設 target 為 cursor"
    exit 1
fi

if [[ "$TARGET" != "cursor" && "$TARGET" != "antigravity" ]]; then
    echo "❌ 錯誤: 未知的 target '$TARGET'，必須是 'cursor' 或 'antigravity'。"
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
    SRC_AGENTS="$SRC_DIR/.cursor/agents"
    DEST_AGENTS="$DEST_BASE/agents"
    SRC_SKILLS="$SRC_DIR/.cursor/skills"
    DEST_SKILLS="$DEST_BASE/skills"
    SRC_CMDS="$SRC_DIR/.cursor/commands"
    DEST_CMDS="$DEST_BASE/commands"
    SRC_MCP="$SRC_DIR/.cursor/mcp.json"
    DEST_MCP="$DEST_BASE/mcp.json"
else
    # Antigravity 僅支援 rules、skills 子目錄，以及 agents/*.md 直接放在 .agents/ 根層
    DEST_BASE="$TARGET_PROJECT/.agents"
    SRC_RULES="$SRC_DIR/rules"
    DEST_RULES="$DEST_BASE/rules"
    SRC_SKILLS="$SRC_DIR/skills"
    DEST_SKILLS="$DEST_BASE/skills"
    # agents/ 底下的文件直接連結到 .agents/ 根層（不放進子目錄）
    SRC_AGENTS="$SRC_DIR/agents"
    DEST_AGENTS="$DEST_BASE"
fi

echo "🔧 正在將 $TARGET 設定 (Links) 佈署至 $DEST_BASE..."

# 顯示目前啟用的語言設定
if [ ${#LANGS[@]} -gt 0 ]; then
    echo "📄 指定載入語言專屬檔案: ${LANGS[*]}"
else
    echo "📄 未指定語言，僅載入通用 (Common) 設定。"
fi
echo "----------------------------------------------------"

mkdir -p "$DEST_BASE"

# 定義建立單筆連結的函式
link_item() {
    local src_file="$1"
    local dest_dir="$2"
    local filename=$(basename "$src_file")
    local dest_path="$dest_dir/$filename"

    mkdir -p "$dest_dir"

    if [ -e "$dest_path" ] && [ ! -L "$dest_path" ]; then
        local backup="${dest_path}_backup_$(date +%Y%m%d_%H%M%S)"
        echo "  📦 備份現有檔案: $filename -> ./${filename}_backup_..."
        mv "$dest_path" "$backup"
    fi
    ln -sfn "$src_file" "$dest_path"
    echo "  🔗 $filename"
}

# 定義按語言過濾後進行連結的核心函式
filter_and_link() {
    local category="$1"
    local src_dir="$2"
    local dest_dir="$3"

    if [ ! -d "$src_dir" ]; then
        return
    fi

    echo "📂 處理 [$category] ..."
    mkdir -p "$dest_dir"

    # 定義語言關鍵字。不論是檔案前綴 (例如 golang-testing.md) 或是資料夾名稱 (例如 golang/) 都適用
    local known_langs=("golang" "go" "typescript" "ts" "python" "django" "java" "springboot" "jpa" "cpp" "rust")

    local linked_count=0

    for src_item in "$src_dir"/*; do
        if [ ! -e "$src_item" ]; then continue; fi
        local basename=$(basename "$src_item")
        
        local should_link=true
        
        # 判斷是否為語言專屬項目
        for klang in "${known_langs[@]}"; do
            if [[ "$basename" == "$klang-"* ]] || [[ "$basename" == "$klang" ]]; then
                should_link=false 
                
                for u_lang in "${LANGS[@]}"; do
                    if [[ "$klang" == "$u_lang" ]] || [[ "$klang" == "$u_lang-"* ]]; then
                        should_link=true
                        break
                    fi
                    
                    # 處理框架語意的擴大相容
                    if [[ "$u_lang" == "python" ]] && [[ "$klang" == "django" ]]; then should_link=true; break; fi
                    if [[ "$u_lang" == "java" ]] && [[ "$klang" == "springboot" || "$klang" == "jpa" ]]; then should_link=true; break; fi
                    if [[ "$u_lang" == "go" ]] && [[ "$klang" == "golang" ]]; then should_link=true; break; fi
                    if [[ "$u_lang" == "golang" ]] && [[ "$klang" == "go" ]]; then should_link=true; break; fi
                    if [[ "$u_lang" == "ts" ]] && [[ "$klang" == "typescript" ]]; then should_link=true; break; fi
                    if [[ "$u_lang" == "typescript" ]] && [[ "$klang" == "ts" ]]; then should_link=true; break; fi
                done
                break 
            fi
        done

        if $should_link; then
            link_item "$src_item" "$dest_dir"
            ((linked_count++))
        fi
    done

    echo "  ✅ 完成 [$category] 連結 ($linked_count 項)"
    echo ""
}

if [[ "$TARGET" == "cursor" ]]; then
    # Cursor: 完整四大類別
    filter_and_link "Rules"             "$SRC_RULES"  "$DEST_RULES"
    filter_and_link "Agents"            "$SRC_AGENTS" "$DEST_AGENTS"
    filter_and_link "Skills"            "$SRC_SKILLS" "$DEST_SKILLS"
    filter_and_link "Commands/Workflows" "$SRC_CMDS"  "$DEST_CMDS"
else
    # Antigravity: 僅支援 rules、skills 子目錄，以及 agents 文件連結至根層
    filter_and_link "Rules"   "$SRC_RULES"   "$DEST_RULES"
    filter_and_link "Skills"  "$SRC_SKILLS"  "$DEST_SKILLS"
    filter_and_link "Agents"  "$SRC_AGENTS"  "$DEST_AGENTS"
fi

echo "----------------------------------------------------"
echo "🎉 $TARGET 全數設定完成！"
