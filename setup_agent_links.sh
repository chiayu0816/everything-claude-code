#!/bin/bash

# 取得腳本所在的目錄 (即專案根目錄)
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
AGENT_DIR="$HOME/.agent"

echo "🔧 正在將 Antigravity 全域設定連結至 $SRC_DIR..."

# 確保 .agent 目錄存在
mkdir -p "$AGENT_DIR"

# 定義連結函式
link_dir() {
    local src_name="$1"
    local dest_subpath="$2"
    local src_path="$SRC_DIR/$src_name"
    local dest_path="$AGENT_DIR/$dest_subpath"

    if [ -d "$src_path" ]; then
        # 如果目標存在且是一般資料夾 (非連結)，先備份
        if [ -d "$dest_path" ] && [ ! -L "$dest_path" ]; then
            local backup="${dest_path}_backup_$(date +%Y%m%d_%H%M%S)"
            echo "📦 發現現有資料夾 $dest_path，正在備份至 $backup"
            mv "$dest_path" "$backup"
        fi
        
        # 確保目標的父目錄存在 (例如 configs/mcp 需要 configs 存在)
        mkdir -p "$(dirname "$dest_path")"

        # 建立符號連結 (使用 -sfn 強制更新連結)
        ln -sfn "$src_path" "$dest_path"
        echo "✅ 連結成功: $src_name -> ~/.agent/$dest_subpath"
    else
        echo "⚠️  來源目錄 $src_name 不存在，跳過。"
    fi
}

# 執行目錄對映與連結
link_dir "skills" "skills"
link_dir "commands" "workflows"
link_dir "agents" "agents"
link_dir "rules" "rules"
link_dir "scripts" "scripts"
link_dir "contexts" "knowledge"
link_dir "tests" "tests"
link_dir "examples" "examples"
link_dir "mcp-configs" "configs/mcp"

echo "🎉 設定完成！現在 Antigravity 已連結到此專案配置。"
