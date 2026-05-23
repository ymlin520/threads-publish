# LINE Webhook Server
# Usage: .\webhook_server.ps1
# Reply "ok" or "publish" in LINE to publish pending_draft.json.

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
            -Body $bytes -ErrorAction Stop | Out-Null
    } catch {
        Write-Log "Reply error: $_"
    }
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

function Verify-LineSignature([string]$Body, [string]$Signature, [string]$Secret) {
    if ([string]::IsNullOrWhiteSpace($Signature)) {
        return $false
    }

    $keyBytes  = [System.Text.Encoding]::UTF8.GetBytes($Secret)
    $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
    $hmac      = [System.Security.Cryptography.HMACSHA256]::new($keyBytes)
    $hash      = $hmac.ComputeHash($bodyBytes)
    $expected  = [Convert]::ToBase64String($hash)

    return $Signature -eq $expected
}

function Send-PlainTextResponse($Response, [int]$StatusCode, [string]$Message) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Message)
    $Response.StatusCode = $StatusCode
    $Response.ContentType = "text/plain; charset=utf-8"
    $Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $Response.Close()
}

$settings = Get-Content $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
$lineToken  = $settings.env.LINE_ACCESS_TOKEN
$lineSecret = $settings.env.LINE_CHANNEL_SECRET

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:$port/webhook/")
$listener.Start()

Write-Log "Webhook server started on port $port"
Write-Log "Endpoint: http://localhost:$port/webhook/"

while ($listener.IsListening) {
    $ctx  = $listener.GetContext()
    $req  = $ctx.Request
    $resp = $ctx.Response

    try {
        if ($req.HttpMethod -eq "GET") {
            Send-PlainTextResponse -Response $resp -StatusCode 200 -Message "OK"
            continue
        }

        if ($req.HttpMethod -ne "POST") {
            Send-PlainTextResponse -Response $resp -StatusCode 405 -Message "Method Not Allowed"
            continue
        }

        $reader  = [System.IO.StreamReader]::new($req.InputStream, [System.Text.Encoding]::UTF8)
        $rawBody = $reader.ReadToEnd()
        $sig     = $req.Headers["x-line-signature"]

        if (-not (Verify-LineSignature -Body $rawBody -Signature $sig -Secret $lineSecret)) {
            Write-Log "Invalid signature, ignoring"
            Send-PlainTextResponse -Response $resp -StatusCode 401 -Message "Invalid signature"
            continue
        }

        $payload = $rawBody | ConvertFrom-Json

        foreach ($event in $payload.events) {
            if ($event.type -ne "message" -or $event.message.type -ne "text") {
                continue
            }

            $text       = $event.message.text.Trim().ToLower()
            $replyToken = $event.replyToken
            Write-Log "Received: $text"

            $confirmWords = @("ok", "okay", "yes", "publish")
            $cancelWords  = @("cancel", "no")

            if ($confirmWords -contains $text) {
                $resultMsg = Publish-Draft
                Send-LineReply -ReplyToken $replyToken -Msg $resultMsg -Token $lineToken
            } elseif ($cancelWords -contains $text) {
                @{ text = ""; scheduled_at = ""; status = "empty" } | ConvertTo-Json | Set-Content $draftPath -Encoding UTF8
                Send-LineReply -ReplyToken $replyToken -Msg "Draft canceled." -Token $lineToken
            } else {
                $draft = if (Test-Path $draftPath) {
                    Get-Content $draftPath -Raw -Encoding UTF8 | ConvertFrom-Json
                } else {
                    @{ status = "empty" }
                }

                $statusMsg = if ($draft.status -eq "pending") {
                    "Draft pending. Reply ok to publish, or cancel to discard."
                } else {
                    "No pending draft."
                }
                Send-LineReply -ReplyToken $replyToken -Msg $statusMsg -Token $lineToken
            }
        }

        Send-PlainTextResponse -Response $resp -StatusCode 200 -Message "OK"
    } catch {
        Write-Log "Error: $_"
        Send-PlainTextResponse -Response $resp -StatusCode 500 -Message "Internal Server Error"
    }
}
