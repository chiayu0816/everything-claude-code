# Project Link Setup Guide (`setup_links.sh`)

這個腳本用於將 `everything-claude-code` 中的 AI 配置（Rules, Agents, Skills, Workflows）透過 **符號連結 (Symlinks)** 的方式建立到目標開發專案中。

與一般複製 (Copy) 不同，使用連結能確保當此倉庫更新時，所有關聯專案都能同步使用最新的 AI 提示詞與規則。

## 🚀 快速開始

### 1. 為 Cursor IDE 設定
如果您使用的是 Cursor，腳本會在目標專案建立 `.cursor/` 目錄並連結相關設定。

```bash
./setup_links.sh --target cursor <目標專案路徑> [語言...]
```

**範例：**
```bash
# 為 TypeScript 專案設定
./setup_links.sh --target cursor ~/projects/my-web-app typescript

# 為 Go 語言專案設定
./setup_links.sh --target cursor ~/projects/my-go-service golang
```

### 2. 為 Antigravity 設定
如果您使用的是 Antigravity 代理環境，腳本會在目標專案建立 `.gemini/` 目錄。

```bash
./setup_links.sh --target antigravity <目標專案路徑> [語言...]
```

**範例：**
```bash
# 為 Python 專案設定 Antigravity 環境
./setup_links.sh --target antigravity ~/projects/ai-research python
```

---

## 🔍 進階功能：語言過濾 (Language Filtering)

本腳本支援「按需求載入」，避免將不相關的開發語言配置塞入您的專案中。

*   **自動載入**：所有不具備語言前綴的通用組件（如 `planner.md`、`coding-style.md` 等）都會自動連結。
*   **精準連結**：只有當您在指令最後方加上語言標籤時，相關的專屬配置才會被載入。
    *   `golang` / `go`：載入 Go 相關規則、Agent 與技能。
    *   `typescript` / `ts`：載入 TS/JS 相關配置。
    *   `python`：載入 Python 與 Django 相關配置。
    *   `java`：載入 Java, SpringBoot 與 JPA 相關配置。

---

## 🧹 移除連結 (Clean Up)

如果您想清除專案中的所有連結，可以使用以下方法：

### 方法 A：使用 find 指令（推薦，最安全）
這會尋找並刪除目錄下的所有「符號連結」，但保留您手動建立的實體檔案。

#### 移除 Cursor 連結：
```bash
find <目標專案路徑>/.cursor -type l -delete
```

#### 移除 Antigravity 連結：
```bash
find <目標專案路徑>/.agent -type l -delete
```

#### 移除全域 ~/.agent 連結：
```bash
find ~/.agent -type l -delete
```

### 方法 B：直接刪除目錄
如果您確定該目錄下沒有任何您想保留的資料：
```bash
rm -rf <目標專案路徑>/.cursor
# 或
rm -rf <目標專案路徑>/.agent
```

---

## ⚠️ 注意事項
*   **備份機制**：如果目標專案中已存在同名的實體資料夾或檔案（非連結），腳本會自動將其改名備份（例如增加時間戳記），確保您的既有設定不會遺失。
*   **執行權限**：執行前請確保腳本具有執行權限：`chmod +x setup_links.sh`。
