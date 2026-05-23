# Threads API Token Auto-Refresh Script
$settingsPath = "$PSScriptRoot\.claude\settings.local.json"
$logPath = "$PSScriptRoot\token_refresh.log"

function Write-Log($msg) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg"
    Add-Content -Path $logPath -Value $line
    Write-Host $line
}

Write-Log "Starting Threads token refresh..."

# Read current settings
$settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
$currentToken = $settings.env.THREADS_ACCESS_TOKEN

# Call refresh API
try {
    $response = Invoke-RestMethod -Uri "https://graph.threads.net/refresh_access_token?grant_type=th_refresh_token&access_token=$currentToken" -Method GET
    $newToken = $response.access_token
    $expiresIn = $response.expires_in

    # Update settings.local.json
    $settings.env.THREADS_ACCESS_TOKEN = $newToken
    $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8

    $expireDays = [math]::Round($expiresIn / 86400)
    Write-Log "Token refreshed successfully. Expires in $expireDays days."
} catch {
    Write-Log "ERROR: Failed to refresh token - $_"
    exit 1
}
