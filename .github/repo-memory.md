# Copilot Repo Memory

## HiDrive Sync Log Extraction

### Current Structure (HiDrive 6.5.x)
- Logs are stored under `$env:LOCALAPPDATA\HiDrive\Logs\` as `log.txt`, `log.0.txt`, etc.
- The primary target is `log.txt` for current runtime logs.

### Legacy Structure (Older HiDrive versions)
- Sync logs were stored under `$env:LOCALAPPDATA\HiDrive\Data\` in subdirectories matching `^\d+\.\d+$` (e.g., `52794237.1`).
- Each directory contained a `syncLog.txt` file.

### syncLog.ps1 Behavior
- Searches for the log entry pattern: `FileSystemSnapshot: Get file system snapshot started. Root <path> |`
- Primary strategy: Searches `$env:LOCALAPPDATA\HiDrive\Logs\log.txt` (current structure)
- Fallback strategy: Searches legacy numeric subdirectories under `$env:LOCALAPPDATA\HiDrive\Data\` (older versions)
- Returns the extracted Root path as a string, or `$null` if not found (no exceptions thrown)
- If no matching entry is found in either location, the script outputs `$null` without error

### Sync Root Storage
- HiDrive stores the configured sync root in SQLite database `$env:LOCALAPPDATA\HiDrive\Data\user.db`
- The relevant value is in table `User`, row/field `SyncFolderPath`
- The module deliberately reads logs instead of SQLite to avoid requiring extra SQLite tools or extensions

## Documentation Preferences

- README should not list the `.Test` folder.
- README should not list the Copilot rule and memory files in `.github`.
- README should mention that AI/KI was used to create this module.
- Keep each sentence on one line in README.md, comments, and comment-based help blocks.
- Use exactly one comment-based help block at the beginning of each PowerShell script or module file.
- Use regular single-line comments for all other comments, with a concise human-readable comment immediately before every function.
- The legacy Copilot rule and memory files are `.github\copilot-instructions.md` and `.github\repo-memory.md`.
- Claude Code uses `CLAUDE.md` at the repository root, which is the maintained rule set.
- Target Windows PowerShell 5.1 and follow Microsoft and PowerShell module-authoring best practices.