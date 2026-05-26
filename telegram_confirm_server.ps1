# Telegram confirmation loop for pending_draft.json.
# Usage:
#   .\telegram_confirm_server.ps1
# Reply in Telegram:
#   ok / publish  -> publish pending draft
#   cancel / no   -> discard pending draft

$settingsPath = "$PSScriptRoot\.claude\settings.local.json"
$draftPath    = "$PSScriptRoot\pending_draft.json"
$statePath    = "$PSScriptRoot\telegram_confirm_state.json"
$logPath      = "$PSScriptRoot\telegram_confirm_server.log"

function Write-Log($msg) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg"
    Add-Content -Path $logPath -Value $line -Encoding UTF8
    Write-Host $line
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

function Invoke-ThreadsAPI([string]$Uri, [hashtable]$Body, [string]$Token) {
    $json  = $Body | ConvertTo-Json -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)

    return Invoke-RestMethod -Uri $Uri -Method POST `
        -Headers @{ "Authorization" = "Bearer $Token"; "Content-Type" = "application/json; charset=utf-8" } `
        -Body $bytes -ErrorAction Stop
}

function Publish-Draft {
    if (-not (Test-Path $draftPath)) {
        return "No pending draft."
    }

    $settings = Get-Content $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $draft = Get-Content $draftPath -Raw -Encoding UTF8 | ConvertFrom-Json

    if ($draft.status -ne "pending") {
        return "No pending draft."
    }

    $threadsToken = $settings.env.THREADS_ACCESS_TOKEN
    $userId       = $settings.env.THREADS_USER_ID

    $containerBody = @{ media_type = "TEXT"; text = $draft.text }
    if ($draft.scheduled_at -ne "") {
        $containerBody["publish_schedule"] = [DateTimeOffset]::Parse($draft.scheduled_at).ToUnixTimeSeconds()
    }

    $container = Invoke-ThreadsAPI -Uri "https://graph.threads.net/v1.0/$userId/threads" -Body $containerBody -Token $threadsToken
    $result = Invoke-ThreadsAPI -Uri "https://graph.threads.net/v1.0/$userId/threads_publish" -Body @{ creation_id = $container.id } -Token $threadsToken

    @{ text = ""; scheduled_at = ""; status = "empty" } | ConvertTo-Json | Set-Content $draftPath -Encoding UTF8

    $label = if ($draft.scheduled_at -ne "") { "scheduled $($draft.scheduled_at)" } else { "published now" }
    Write-Log "Published! Post ID: $($result.id) [$label]"

    return "Threads published. Post ID: $($result.id)`n[$label]"
}

function Clear-Draft {
    @{ text = ""; scheduled_at = ""; status = "empty" } | ConvertTo-Json | Set-Content $draftPath -Encoding UTF8
}

function Get-Offset {
    if (-not (Test-Path $statePath)) {
        return 0
    }

    try {
        $state = Get-Content $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
        return [int64]$state.offset
    } catch {
        return 0
    }
}

function Save-Offset([int64]$Offset) {
    @{ offset = $Offset } | ConvertTo-Json | Set-Content $statePath -Encoding UTF8
}

$settings = Get-Content $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
$telegramToken  = $settings.env.TELEGRAM_BOT_TOKEN
$telegramChatId = [string]$settings.env.TELEGRAM_CHAT_ID

if ([string]::IsNullOrWhiteSpace($telegramToken) -or [string]::IsNullOrWhiteSpace($telegramChatId)) {
    throw "TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID is missing. Run .\bind_telegram.ps1 first."
}

Write-Log "Telegram confirmation loop started."
Write-Log "Listening for chat id $telegramChatId. Press Ctrl+C to stop."

while ($true) {
    try {
        $offset = Get-Offset
        $updates = Invoke-RestMethod -Uri "https://api.telegram.org/bot$telegramToken/getUpdates?offset=$offset&timeout=25" -Method GET -ErrorAction Stop

        foreach ($update in @($updates.result)) {
            Save-Offset -Offset ([int64]$update.update_id + 1)

            if (-not $update.message -or -not $update.message.text) {
                continue
            }

            $incomingChatId = [string]$update.message.chat.id
            if ($incomingChatId -ne $telegramChatId) {
                Write-Log "Ignored message from unauthorized chat id $incomingChatId"
                continue
            }

            $text = $update.message.text.Trim().ToLower()
            Write-Log "Received: $text"

            $confirmWords = @("ok", "okay", "yes", "publish")
            $cancelWords  = @("cancel", "no")

            if ($confirmWords -contains $text) {
                $resultMsg = Publish-Draft
                Send-TelegramMessage -Message $resultMsg -BotToken $telegramToken -ChatId $telegramChatId
            } elseif ($cancelWords -contains $text) {
                Clear-Draft
                Send-TelegramMessage -Message "Draft canceled." -BotToken $telegramToken -ChatId $telegramChatId
            } else {
                $draft = if (Test-Path $draftPath) {
                    Get-Content $draftPath -Raw -Encoding UTF8 | ConvertFrom-Json
                } else {
                    @{ status = "empty" }
                }

                $statusMsg = if ($draft.status -eq "pending") {
                    "Draft pending. Reply ok/publish to confirm, or cancel to discard."
                } else {
                    "No pending draft."
                }
                Send-TelegramMessage -Message $statusMsg -BotToken $telegramToken -ChatId $telegramChatId
            }
        }
    } catch {
        Write-Log "Error: $_"
        Start-Sleep -Seconds 5
    }
}
