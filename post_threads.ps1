# Threads API 發文腳本（UTF-8 encoding 修正版）
# 用法：
#   立即發文：  .\post_threads.ps1 -Text "內容"
#   排程發文：  .\post_threads.ps1 -Text "內容" -ScheduleAt "2026-05-24T16:40:00+08:00"
#   LINE 預覽： .\post_threads.ps1 -Text "內容" -LinePreview -ScheduleAt "2026-05-24T16:40:00+08:00"
#              → 存進 pending_draft.json，送 LINE 預覽，等用戶回 "ok" 再發

param(
    [Parameter(Mandatory=$true)]
    [string]$Text,
    [string]$ScheduleAt  = "",
    [switch]$LinePreview
)

$settingsPath = "$PSScriptRoot\.claude\settings.local.json"
$draftPath    = "$PSScriptRoot\pending_draft.json"
$logPath      = "$PSScriptRoot\post_threads.log"

function Write-Log($msg) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg"
    Add-Content -Path $logPath -Value $line -Encoding UTF8
    Write-Host $line
}

function Invoke-ThreadsAPI([string]$Uri, [hashtable]$Body, [string]$Token) {
    $json  = $Body | ConvertTo-Json -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    return Invoke-RestMethod -Uri $Uri -Method POST `
        -Headers @{ "Authorization" = "Bearer $Token"; "Content-Type" = "application/json; charset=utf-8" } `
        -Body $bytes
}

$settings = Get-Content $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
$threadsToken = $settings.env.THREADS_ACCESS_TOKEN
$userId       = $settings.env.THREADS_USER_ID
$lineToken    = $settings.env.LINE_ACCESS_TOKEN
$lineUserId   = $settings.env.LINE_USER_ID

# ── LINE 預覽模式：存草稿，送 LINE，等確認 ──────────────────────────
if ($LinePreview) {
    Write-Log "Saving draft for LINE preview..."

    @{
        text         = $Text
        scheduled_at = $ScheduleAt
        status       = "pending"
    } | ConvertTo-Json -Depth 3 | Set-Content $draftPath -Encoding UTF8

    $scheduleLabel = if ($ScheduleAt -ne "") { "排程：$ScheduleAt" } else { "立即發布" }
    $lineMsg = "【Threads 草稿預覽】`n$scheduleLabel`n`n$Text`n`n---`n回覆「ok」發布 / 「取消」取消"
    $lineBody  = @{ to = $lineUserId; messages = @(@{ type = "text"; text = $lineMsg }) } | ConvertTo-Json -Depth 5 -Compress
    $lineBytes = [System.Text.Encoding]::UTF8.GetBytes($lineBody)

    try {
        Invoke-RestMethod -Uri "https://api.line.me/v2/bot/message/push" -Method POST `
            -Headers @{ "Authorization" = "Bearer $lineToken"; "Content-Type" = "application/json; charset=utf-8" } `
            -Body $lineBytes | Out-Null
        Write-Log "LINE preview sent. Waiting for confirmation..."
        Write-Host "草稿已存入 pending_draft.json，LINE 預覽已送出。"
        Write-Host "在 LINE 回覆「ok」即可發布。"
    } catch {
        Write-Log "LINE send failed: $_"
        Write-Host "LINE 發送失敗：$_"
    }
    return
}

# ── 直接發文模式 ─────────────────────────────────────────────────────
Write-Log "Starting Threads post..."

$containerBody = @{ media_type = "TEXT"; text = $Text }
if ($ScheduleAt -ne "") {
    $epoch = [DateTimeOffset]::Parse($ScheduleAt).ToUnixTimeSeconds()
    $containerBody["publish_schedule"] = $epoch
    Write-Log "Scheduled for: $ScheduleAt (epoch: $epoch)"
}

$container = Invoke-ThreadsAPI -Uri "https://graph.threads.net/v1.0/$userId/threads" -Body $containerBody -Token $threadsToken
Write-Log "Container created: $($container.id)"

$result = Invoke-ThreadsAPI -Uri "https://graph.threads.net/v1.0/$userId/threads_publish" -Body @{ creation_id = $container.id } -Token $threadsToken
Write-Log "Post published! ID: $($result.id)"
Write-Host "SUCCESS: Post ID = $($result.id)"
