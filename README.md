# Queue Processor

A batch script system for queuing and extracting archives to specified destinations.

## Files

| File | Description |
|------|-------------|
| `add-to-queue.bat` | Adds files to the extraction queue with auto-detection or destination choice |
| `process-queue.bat` | Processes the queue, extracts archives, and moves contents |
| `queue.txt` | The queue file (created automatically) |
| `queue.log` | Log file with timestamps (created automatically) |
| `queue.lock` | Lock file to prevent multiple instances (created automatically) |

## Usage

### Adding to Queue

Drag and drop an archive onto `add-to-queue.bat`, or run from command line:

```
add-to-queue.bat "C:\path\to\archive.rar"
```

> **Tip — Send To integration:** Add a shortcut to `add-to-queue.bat` in your Send To folder so you can right-click any archive and choose **Send to → add-to-queue**. Open the Send To folder by pressing `Win+R` and typing `shell:sendto`, then create a shortcut to `add-to-queue.bat` there.

If the archive path contains a folder named exactly `TV` or `Movies`, the destination is chosen automatically. Otherwise you are prompted:

- [1] E:\TV
- [2] I:\Movies
- [3] E:\Other
- [4] Cancel

The queue processor starts automatically if it is not already running.

### Processing the Queue

Run `process-queue.bat` to start processing. It will:

1. Extract each queued archive to the staging folder (showing progress %)
2. Display the current queue at the start of each job
3. Move extracted contents to the destination (showing filename and animation)
4. Delete the source archive (if enabled)
5. Log the result

The processor exits automatically when the queue is empty. Starting `add-to-queue.bat` will relaunch it as needed.

## How extraction and moving works

Each job runs in two distinct phases, designed to keep read and write heads on separate drives and avoid contention:

**Phase 1 — Extract**
7-Zip reads the archive from its source location and writes the extracted files to `STAGING`. For best performance, put `STAGING` on a drive that is neither the source drive nor the destination drive — ideally a fast intermediate disk (SSD or a dedicated spinner). This means the source drive only reads and the staging drive only writes during this phase.

**Phase 2 — Move**
Robocopy moves the extracted files from `STAGING` to the destination using `/MOV`. Because it is a move rather than a copy, robocopy reads from the staging drive and writes to the destination drive, then deletes the source. The original source archive is not touched during this phase.

The result is that no two phases compete for the same drive at the same time:

```
Source drive  →  [Extract]  →  Staging drive  →  [Move]  →  Destination drive
   (read)                         (write then read)               (write)
```

`STAGING` is wiped after each job regardless of success or failure, so disk space is only used for one archive at a time.

## Configuration

All settings live in `config.env` in the same folder as the scripts. If the file does not exist it is created automatically with placeholder values on first run — edit it before using.

| Key | Description |
|-----|-------------|
| `SEVENZIP` | Full path to `7z.exe` |
| `STAGING` | Temporary extraction folder |
| `DESTINATIONS` | Pipe-separated `Label:Path` pairs, e.g. `TV:E:\TV\|Movies:I:\Movies\|Other:E:\Other` |
| `AUTODETECT` | Pipe-separated folder names, e.g. `TV\|Movies` — if a folder in the source path exactly matches one of these (case-insensitive) the corresponding destination is chosen automatically |

Example `config.env`:

```ini
SEVENZIP=C:\Program Files\7-Zip\7z.exe
STAGING=T:\queue\STAGING
DESTINATIONS=TV:E:\TV|Movies:I:\Movies|Other:E:\Other
AUTODETECT=TV|Movies
```

## Troubleshooting

### "Another instance is already running"

If the processor was force-closed, the lock file may still exist. Delete it manually:

```
del T:\queue\queue.lock
```

A warning is written to `queue.log` whenever startup is blocked by a stale lock, so you can distinguish this from a real extraction failure in the log.

### Queue format

Each line in `queue.txt` follows this format:

```
"C:\path\to\archive.rar";;E:\Destination
```

The delimiter is `;;` (double semicolon).

## Requirements

- Windows
- [7-Zip](https://www.7-zip.org/) installed at `C:\Program Files\7-Zip\7z.exe`
