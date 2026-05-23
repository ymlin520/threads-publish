# LINE Webhook Server
# 用法：.\webhook_server.ps1
# LINE 傳 "ok"/"好"/"確認"/"發" → 自動發布 pending_draft.json 的草稿

$settingsPath = "$PSScriptRoot\.claude\settings.local.json"
$draftPath    = "$PSScriptRoot\pending_draft.json"
$logPath      = "$PSScriptRoot\webhook_server.log"
$port         = 8080

function Write-Log($msg) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg"
    Add-Content -Path $logPath -Value $line -Encoding UTF8
    Write-Host $line
}

function Send-LineReply([string]$ReplyToken, [string]$Msg, [string]$Token) {
    $body = @{
        replyToken = $ReplyToken
        messages   = @(@{ type = "text"; text = $Msg })
    } | ConvertTo-Json -Depth 5 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
    try {
        Invoke-RestMethod -Uri "https://api.line.me/v2/bot/message/reply" -Method POST `
            -Headers @{ "Authorization" = "Bearer $Token"; "Content-Type" = "application/json; charset=utf-8" } `
            -Body $bytes | Out-Null
    } catch { Write-Log "Reply error: $_" }
}

function Publish-Draft([string]$Token) {
    $settings = Get-Content $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $draft = Get-Content $draftPath -Raw -Encoding UTF8 | ConvertFrom-Json

    if ($draft.status -ne "pending") { return "目前沒有待確認的草稿" }

    $lineToken    = $settings.env.LINE_ACCESS_TOKEN
    $threadsToken = $settings.env.THREADS_ACCESS_TOKEN
    $userId       = $settings.env.THREADS_USER_ID

    function Invoke-ThreadsAPI([string]$Uri, [hashtable]$Body, [string]$Tok) {
        $json  = $Body | ConvertTo-Json -Compress
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
        return Invoke-RestMethod -Uri $Uri -Method POST `
            -Headers @{ "Authorization" = "Bearer $Tok"; "Content-Type" = "application/json; charset=utf-8" } `
            -Body $bytes
    }

    $containerBody = @{ media_type = "TEXT"; text = $draft.text }
    if ($draft.scheduled_at -ne "") {
        $containerBody["publish_schedule"] = [DateTimeOffset]::Parse($draft.scheduled_at).ToUnixTimeSeconds()
    }

    $container  = Invoke-ThreadsAPI -Uri "https://graph.threads.net/v1.0/$userId/threads" -Body $containerBody -Tok $threadsToken
    $pubResult  = Invoke-ThreadsAPI -Uri "https://graph.threads.net/v1.0/$userId/threads_publish" -Body @{ creation_id = $container.id } -Tok $threadsToken

    # 清除草稿
    @{ text = ""; scheduled_at = ""; status = "empty" } | ConvertTo-Json | Set-Content $draftPath -Encoding UTF8

    $label = if ($draft.scheduled_at -ne "") { "排程 $($draft.scheduled_at)" } else { "立即" }
    Write-Log "Published! Post ID: $($pubResult.id) [$label]"
    return "✅ 已發布！Post ID: $($pubResult.id)`n[$label]"
}

function Verify-LineSignature([string]$Body, [string]$Signature, [string]$Secret) {
    $keyBytes  = [System.Text.Encoding]::UTF8.GetBytes($Secret)
    $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
    $hmac      = [System.Security.Cryptography.HMACSHA256]::new($keyBytes)
    $hash      = $hmac.ComputeHash($bodyBytes)
    $expected  = [Convert]::ToBase64String($hash)
    return $Signature -eq $expected
}

# 啟動 HTTP Listener
$settings = Get-Content $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
$lineToken   = $settings.env.LINE_ACCESS_TOKEN
$lineSecret  = $settings.env.LINE_CHANNEL_SECRET

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://+:$port/webhook/")
$listener.Start()
Write-Log "Webhook server started on port $port"
Write-Log "Endpoint: http://localhost:$port/webhook/"

while ($listener.IsListening) {
    $ctx     = $listener.GetContext()
    $req     = $ctx.Request
    $resp    = $ctx.Response

    try {
        $reader  = [System.IO.StreamReader]::new($req.InputStream, [System.Text.Encoding]::UTF8)
        $rawBody = $reader.ReadToEnd()
        $sig     = $req.Headers["x-line-signature"]

        # 簽名驗證
        if (-not (Verify-LineSignature -Body $rawBody -Signature $sig -Secret $lineSecret)) {
            Write-Log "Invalid signature, ignoring"
            $resp.StatusCode = 401
            $resp.Close()
            continue
        }

        $payload = $rawBody | ConvertFrom-Json
        foreach ($event in $payload.events) {
            if ($event.type -ne "message" -or $event.message.type -ne "text") { continue }

            $text       = $event.message.text.Trim().ToLower()
            $replyToken = $event.replyToken
            Write-Log "Received: $text"

            $confirmWords = @("ok", "好", "確認", "發", "發布", "publish")
            $cancelWords  = @("取消", "cancel", "不要", "停")

            if ($confirmWords -contains $text) {
                $result = Publish-Draft -Token $lineToken
                Send-LineReply -ReplyToken $replyToken -Msg $result -Token $lineToken

            } elseif ($cancelWords -contains $text) {
                @{ text = ""; scheduled_at = ""; status = "empty" } | ConvertTo-Json | Set-Content $draftPath -Encoding UTF8
                Send-LineReply -ReplyToken $replyToken -Msg "❌ 已取消草稿。" -Token $lineToken

            } else {
                $draft = Get-Content $draftPath -Raw -Encoding UTF8 | ConvertFrom-Json
                $statusMsg = if ($draft.status -eq "pending") {
                    "草稿等待確認中。`n回覆「ok」發布 / 「取消」取消。"
                } else {
                    "目前沒有待確認草稿。"
                }
                Send-LineReply -ReplyToken $replyToken -Msg $statusMsg -Token $lineToken
            }
        }

        $resp.StatusCode = 200
        $resp.Close()

    } catch {
        Write-Log "Error: $_"
        $resp.StatusCode = 500
        $resp.Close()
    }
}
