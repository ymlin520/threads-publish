# Integration Notes

This workspace combines the local Threads/LINE publishing scripts with the
AK-Threads-Booster operating system.

- Use `AGENTS.md` and `SKILL.md` for AK-Threads-Booster routing.
- Use `post_threads.ps1` for direct Threads publishing and LINE draft previews.
- Use `webhook_server.ps1` for LINE confirmation replies: `ok` publishes, `cancel` discards.
- Use `bind_telegram.ps1` to save Telegram bot credentials into `.claude/settings.local.json`.
- Use `telegram_confirm_server.ps1` for Telegram confirmation replies: `ok` publishes, `cancel` discards.
- Keep `.claude/settings.local.json`, logs, draft state, and runtime tracker/cache files local only.
- LINE API requests that contain Chinese text must send UTF-8 bytes with `application/json; charset=utf-8`.
- Telegram API requests that contain Chinese text must send UTF-8 bytes with `application/json; charset=utf-8`.

## Telegram Binding

1. In Telegram, open `@BotFather`, create a bot, and copy the bot token.
2. Send any message to the new bot.
3. Run `.\bind_telegram.ps1 -BotToken "YOUR_BOT_TOKEN"`.
4. Start confirmations with `.\telegram_confirm_server.ps1`.
5. Send a draft preview with `.\post_threads.ps1 -Text "..." -TelegramPreview`.
