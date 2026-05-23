# Integration Notes

This workspace combines the local Threads/LINE publishing scripts with the
AK-Threads-Booster operating system.

- Use `AGENTS.md` and `SKILL.md` for AK-Threads-Booster routing.
- Use `post_threads.ps1` for direct Threads publishing and LINE draft previews.
- Use `webhook_server.ps1` for LINE confirmation replies: `ok` publishes, `cancel` discards.
- Keep `.claude/settings.local.json`, logs, draft state, and runtime tracker/cache files local only.
- LINE API requests that contain Chinese text must send UTF-8 bytes with `application/json; charset=utf-8`.

