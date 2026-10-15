# log-rotate-lite

**Stop log files from eating your disk: one small script, dry-run first, no surprises.**

## What it does

Looks at one folder and:

1. Compresses log files (default `*.log`) that have reached a minimum size to `name.log.<yyyymmdd-HHMMSS>.gz`, verifies the archive, then empties the original (copy-truncate, so programs that keep the log open keep working).
2. Deletes archives of that naming scheme that are older than N days.

Safety: **dry-run by default** (add `--apply` / `-Apply` to act), no network access, never goes into sub-folders, never touches anything outside the folder you pass, never deletes an original unless it was compressed and verified (the original is only emptied, not removed).

Two equivalent versions: `rotate-logs-lite.sh` (Linux) and `Rotate-Logs-Lite.ps1` (Windows).

## Quick start

Linux:

```bash
chmod +x rotate-logs-lite.sh
./rotate-logs-lite.sh /var/log/myapp                        # preview only
./rotate-logs-lite.sh /var/log/myapp --min-kb 512 --keep-days 14 --apply
```

Windows (PowerShell):

```powershell
.\Rotate-Logs-Lite.ps1 -Path C:\Logs                        # preview only
.\Rotate-Logs-Lite.ps1 -Path C:\Logs -MinKB 512 -KeepDays 14 -Apply
```

Options: pattern (`--pattern '*.log'` / `-Filter`), minimum size in KB (default 1024), keep days (default 30, 0 = never delete archives).

Exit codes: 0 ok, 1 finished with warnings, 2 usage error.

## Requirements

- Linux: Bash 4+, gzip, GNU coreutils (`stat`, `find`).
- Windows: PowerShell 5.1 or 7 (no extra modules).

## Notes

Test on a copy of your logs first. Provided as is, see LICENSE.

Created with AI assistance by an automated system.

## Full version

The lite version rotates one folder per call. The full "Backup & Log Rotation Scripts" kit adds, honestly listed:

- Folder backup scripts (Linux and Windows) in addition to log rotation
- A config file for several folders and patterns at once
- Keep-by-count in addition to keep-by-days, plus a `rename` rotation method
- A run logfile for every execution, with summaries and exit codes for monitoring
- Self-test scripts and a scheduling guide (cron, systemd, Task Scheduler)

Get it here: https://kontor7-agent.github.io/p/backup-log-rotation-scripts?s=github
