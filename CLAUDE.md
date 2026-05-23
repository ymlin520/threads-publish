# AK Threads Booster — 專案設定

## 發文前必做：UTF-8 編碼處理

**問題根源：** PowerShell `ConvertTo-Json` 產生 UTF-16 字串，直接傳給 `Invoke-RestMethod -Body` 時，中文字會變成 `???????`。

**必須使用 `post_threads.ps1`** 發所有文章，禁止直接在 PowerShell 用 `-Body $jsonString` 傳送。

```powershell
# ✅ 正確做法（post_threads.ps1 內建）
$jsonString = $body | ConvertTo-Json -Compress
$bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonString)
Invoke-RestMethod -Uri $url -Method POST -Headers $headers -Body $bodyBytes

# ❌ 錯誤（中文會亂碼）
$body = $payload | ConvertTo-Json -Compress
Invoke-RestMethod -Uri $url -Body $body
```

**正確的發文指令：**
```powershell
# 立即發文
.\post_threads.ps1 -Text "文章內容..."

# 排程發文（台灣時間，記得帶 +08:00）
.\post_threads.ps1 -Text "文章內容..." -ScheduleAt "2026-05-24T16:40:00+08:00"
```

---

## LINE 預覽 + Webhook 確認流程

### 標準發文流程（LINE 互動版）

```powershell
# 1. 產生草稿後，送 LINE 預覽（存入 pending_draft.json）
.\post_threads.ps1 -Text "文章內容..." -LinePreview
.\post_threads.ps1 -Text "文章內容..." -LinePreview -ScheduleAt "2026-05-24T16:40:00+08:00"

# 2. 用戶在 LINE 回覆：
#    「ok」/「好」/「確認」/「發」 → webhook_server.ps1 自動發布
#    「取消」/「不要」 → 清除草稿
```

### Webhook Server 啟動

```powershell
# 在背景執行，保持開著
.\webhook_server.ps1
# 監聽 http://localhost:8080/webhook/
# 需要 ngrok 或固定 IP 對外公開，再填入 LINE Developer Console
```

### Webhook 設定步驟
1. 執行 `.\webhook_server.ps1`（保持開著）
2. 用 ngrok：`ngrok http 8080` → 複製 https URL
3. LINE Developer Console → Messaging API → Webhook URL 填入 `https://xxxx.ngrok.io/webhook/`
4. 把 ngrok URL 更新到 `settings.local.json` 的 `LINE_WEBHOOK_URL`

### 草稿暫存
- `pending_draft.json` — 暫存待確認的草稿（text + scheduled_at + status）
- status: `"pending"` = 等待確認，`"empty"` = 無草稿

LINE 和 Threads 的 API 呼叫都必須用 UTF-8 bytes，不能用字串直接傳。

---

## 知識庫位置

- `brand_voice.md` — 15 維語氣指紋，/draft 時參照
- `knowledge/concept-library.md` — 各主題核心洞察與故事切入點
- `knowledge/hostswp-articles.md` — 原始爬取文章
- `knowledge/topics-index.md` — 已收錄文章索引

## 環境變數

存放於 `.claude/settings.local.json`（gitignore 保護）：
- `THREADS_ACCESS_TOKEN` — 每 60 天到期，`refresh_token.ps1` 每 30 天自動續期
- `THREADS_USER_ID`
- `LINE_ACCESS_TOKEN`
- `LINE_CHANNEL_SECRET`
- `LINE_USER_ID`
