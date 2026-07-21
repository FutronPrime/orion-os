# Durable background jobs — never `nohup … &` from a short-lived shell

A long-running job launched with `nohup cmd &` inside a short-lived shell (a tool call, a subshell an
orchestrator tears down between turns) gets **reaped when that shell exits**. It looks backgrounded; it
isn't — the process dies mid-run and progress silently freezes.

`nohup` only ignores SIGHUP. It does **not** make the process survive its parent shell being torn down.

## Do this instead (durable — pick one)
1. **A scheduler/service** — launchd (`~/Library/LaunchAgents/*.plist`) on macOS, systemd unit / `nohup`
   from a real service manager on Linux. Survives shell exit, logout, reboot.
2. **A harness-tracked background run** — when your agent/orchestrator supervises the process and notifies
   on completion (survives between turns).
3. **A supervised daemon**, not a bare `&`.

## Then verify
"Launched" ≠ "running". After starting durable work, confirm progress advances (a count, a heartbeat,
a log line) before reporting it as running. This is a *persistence* discipline: don't let work die quietly.
