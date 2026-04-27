# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A Windows batch script system for queuing archive files (RAR, ZIP, etc.) and extracting them to configured destinations using 7-Zip and robocopy.

## How It Works

**Adding to queue:** Drag an archive onto `add-to-queue.bat` (or pass path as argument). It uses PowerShell to split the path into components and checks if any component exactly equals `TV` or `Movies` (case-insensitive) — if so, the destination is chosen automatically. Otherwise the user is prompted. The entry is appended to `queue.txt` as:
```
"C:\path\to\archive.rar";;E:\Destination
```
If `queue.lock` does not exist, the processor is started automatically via `start`.

**Processing:** `process-queue.bat` processes one entry at a time, then `goto loop`s to re-read the file. For each entry it:
1. Shows the current queue (static snapshot)
2. Extracts to `STAGING` via 7-Zip (`-bso0 -bsp1` to suppress headers, keep % progress)
3. Moves contents to destination via a PowerShell-wrapped robocopy with a live filename + animation display
4. Cleans up `STAGING`
5. Removes the processed line from `queue.txt`
6. Logs success/failure with timestamp to `queue.log`

When the queue is empty the processor exits and deletes `queue.lock`. The next `add-to-queue.bat` drop restarts it.

## Configuration

All user-specific values live in `config.env` (same directory as the scripts). Both bat files load it at startup using a `for /f "tokens=1,* delims==" %%A` loop; lines starting with `#` are skipped via `!_K:~0,1!` delayed-expansion check. If `config.env` is missing, `:bootstrap_config` creates a placeholder copy and the script exits so the user can edit it.

Keys: `SEVENZIP`, `STAGING`, `DESTINATIONS` (pipe-separated `Label:Path` pairs), `AUTODETECT` (pipe-separated folder names matched to destination labels).

Queue/log/lock files use `%~dp0` (the script's own directory) and are not in config — they are operational, not user config.

## Requirements

- Windows 10/11 with PowerShell 5.1+
- [7-Zip](https://www.7-zip.org/) at `C:\Program Files\7-Zip\7z.exe`
- No build step — `robocopy`, `choice`, `timeout` are built-in

## Key Implementation Notes

**Quoting hazard:** `process-queue.bat` uses `setlocal EnableDelayedExpansion`. Any `!` inside a PowerShell `-Command "..."` string is intercepted by batch's delayed expansion engine. Use `-not` instead of `!` as the PowerShell NOT operator. Similarly, `"` inside a batch double-quoted string closes it early — use `[char]13` instead of `` `r ``, single-quoted strings, and `[char]N` for any character that would require a double-quoted escape.

**Lock file:** A stale `queue.lock` (left by a killed process) blocks startup and writes a warning to `queue.log`. Delete it manually to resume.

**Robocopy exit codes:** Robocopy returns 0–7 for varying levels of success. The current script does not treat these as failures — the `||` error path only triggers if 7-Zip itself fails.

**`for /f` delimiter behaviour:** The queue delimiter `;;` — batch `for /f` treats consecutive identical delimiters as one, so `tokens=1,2 delims=;` correctly maps to path and destination despite the double semicolon.
