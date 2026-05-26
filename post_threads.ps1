# Threads API publishing helper.
# Usage:
#   .\post_threads.ps1 -Text "post text"
#   .\post_threads.ps1 -Text "post text" -ScheduleAt "2026-05-24T16:40:00+08:00"
#   .\post_threads.ps1 -Text "post text" -LinePreview
#   .\post_threads.ps1 -Text "post text" -TelegramPreview

param(
    [Parameter(Mandatory=$true)]
    [string]$Text,
    [string]$ScheduleAt = "",
    [switch]$LinePreview,
    [switch]$TelegramPreview
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
        -Body $bytes -ErrorAction Stop
}

function Send-LinePush([string]$Message, [string]$Token, [string]$UserId) {
    $body = @{
        to       = $UserId
        messages = @(@{ type = "text"; text = $Message })
    } | ConvertTo-Json -Depth 5 -Compress

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)

    Invoke-RestMethod -Uri "https://api.line.me/v2/bot/message/push" -Method POST `
        -Headers @{ "Authorization" = "Bearer $Token"; "Content-Type" = "application/json; charset=utf-8" } `
        -Body $bytes -ErrorAction Stop | Out-Null
}

function Send-TelegramMessage([string]$Message, [string]$BotToken, [string]$ChatId) {
    $body = @{
        chat_id = $ChatId
        text    = $Message
    } | ConvertTo-Json -Depth 5 -Compress

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)

    Invoke-RestMethod -Uri "https://api.telegram.org/bot$BotToken/sendMessage" -Method POST `
        -Headers @{ "Content-Type" = "application/json; charset=utf-8" } `
        -Body $bytes -ErrorAction Stop | Out-Null
}

function Save-PendingDraft([string]$DraftText, [string]$DraftScheduleAt) {
    @{
        text         = $DraftText
        scheduled_at = $DraftScheduleAt
        status       = "pending"
    } | ConvertTo-Json -Depth 3 | Set-Content $draftPath -Encoding UTF8
}

function Get-ScheduleLabel([string]$DraftScheduleAt) {
    if ($DraftScheduleAt -ne "") {
        return "Scheduled: $DraftScheduleAt"
    }

    return "Publish now"
}

$settings = Get-Content $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
$threadsToken = $settings.env.THREADS_ACCESS_TOKEN
$userId       = $settings.env.THREADS_USER_ID

if ($LinePreview -and $TelegramPreview) {
    throw "Choose only one preview channel: -LinePreview or -TelegramPreview."
}

if ($LinePreview) {
    $lineToken  = $settings.env.LINE_ACCESS_TOKEN
    $lineUserId = $settings.env.LINE_USER_ID

    if ([string]::IsNullOrWhiteSpace($lineToken) -or [string]::IsNullOrWhiteSpace($lineUserId)) {
        throw "LINE_ACCESS_TOKEN or LINE_USER_ID is missing in .claude/settings.local.json."
    }

    Write-Log "Saving draft for LINE preview..."
    Save-PendingDraft -DraftText $Text -DraftScheduleAt $ScheduleAt

    $lineMsg = "Threads draft preview`n$(Get-ScheduleLabel $ScheduleAt)`n`n$Text`n`n---`nReply ok/publish to confirm, or cancel to discard."
    Send-LinePush -Message $lineMsg -Token $lineToken -UserId $lineUserId

    Write-Log "LINE preview sent. Waiting for confirmation..."
    Write-Host "Draft saved to pending_draft.json. Reply in LINE with ok/publish or cancel."
    return
}

if ($TelegramPreview) {
    $telegramToken  = $settings.env.TELEGRAM_BOT_TOKEN
    $telegramChatId = $settings.env.TELEGRAM_CHAT_ID

    if ([string]::IsNullOrWhiteSpace($telegramToken) -or [string]::IsNullOrWhiteSpace($telegramChatId)) {
        throw "TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID is missing in .claude/settings.local.json. Run .\bind_telegram.ps1 first."
    }

    Write-Log "Saving draft for Telegram preview..."
    Save-PendingDraft -DraftText $Text -DraftScheduleAt $ScheduleAt

    $telegramMsg = "Threads draft preview`n$(Get-ScheduleLabel $ScheduleAt)`n`n$Text`n`n---`nReply ok/publish to confirm, or cancel to discard."
    Send-TelegramMessage -Message $telegramMsg -BotToken $telegramToken -ChatId $telegramChatId

    Write-Log "Telegram preview sent. Waiting for confirmation..."
    Write-Host "Draft saved to pending_draft.json. Run telegram_confirm_server.ps1 and reply in Telegram with ok/publish or cancel."
    return
}

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
