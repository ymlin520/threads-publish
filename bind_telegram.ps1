# Bind Telegram credentials into .claude/settings.local.json.
# 1. Create a Telegram bot with @BotFather and copy the bot token.
# 2. Send any message to your bot.
# 3. Run:
#      .\bind_telegram.ps1 -BotToken "123:abc"
#    The script will detect the latest chat id and save both values.
#    You can also pass -ChatId directly.

param(
    [Parameter(Mandatory=$true)]
    [string]$BotToken,
    [string]$ChatId = ""
)

$settingsPath = "$PSScriptRoot\.claude\settings.local.json"

function Get-TelegramChatId([string]$Token) {
    $updates = Invoke-RestMethod -Uri "https://api.telegram.org/bot$Token/getUpdates" -Method GET -ErrorAction Stop
    $messages = @($updates.result | Where-Object { $_.message -and $_.message.chat -and $_.message.chat.id })

    if ($messages.Count -eq 0) {
        throw "No Telegram chat found. Send a message to your bot first, then run this script again."
    }

    return [string]$messages[-1].message.chat.id
}

function Send-TelegramMessage([string]$Token, [string]$TargetChatId, [string]$Message) {
    $body = @{
        chat_id = $TargetChatId
        text    = $Message
    } | ConvertTo-Json -Depth 5 -Compress

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)

    Invoke-RestMethod -Uri "https://api.telegram.org/bot$Token/sendMessage" -Method POST `
        -Headers @{ "Content-Type" = "application/json; charset=utf-8" } `
        -Body $bytes -ErrorAction Stop | Out-Null
}

if (-not (Test-Path $settingsPath)) {
    New-Item -ItemType Directory -Path (Split-Path $settingsPath) -Force | Out-Null
    @{ env = @{} } | ConvertTo-Json -Depth 5 | Set-Content $settingsPath -Encoding UTF8
}

if ([string]::IsNullOrWhiteSpace($ChatId)) {
    $ChatId = Get-TelegramChatId -Token $BotToken
}

$settings = Get-Content $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $settings.env) {
    $settings | Add-Member -MemberType NoteProperty -Name env -Value ([pscustomobject]@{})
}

if ($settings.env.PSObject.Properties.Name -contains "TELEGRAM_BOT_TOKEN") {
    $settings.env.TELEGRAM_BOT_TOKEN = $BotToken
} else {
    $settings.env | Add-Member -MemberType NoteProperty -Name TELEGRAM_BOT_TOKEN -Value $BotToken
}

if ($settings.env.PSObject.Properties.Name -contains "TELEGRAM_CHAT_ID") {
    $settings.env.TELEGRAM_CHAT_ID = $ChatId
} else {
    $settings.env | Add-Member -MemberType NoteProperty -Name TELEGRAM_CHAT_ID -Value $ChatId
}

$settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
Send-TelegramMessage -Token $BotToken -TargetChatId $ChatId -Message "Telegram is now bound to AK-Threads-Booster."

Write-Host "Telegram binding saved."
Write-Host "Chat ID: $ChatId"
