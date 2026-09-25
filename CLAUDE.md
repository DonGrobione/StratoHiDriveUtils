# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

StratoHiDriveUtils is a small, dependency-free Windows PowerShell 5.1 module for controlling the STRATO HiDrive desktop client: `Start-HiDrive`, `Stop-HiDrive`, `Get-HiDriveSyncRoot`, and the self-updater `Update-StratoHiDriveUtils`. All code lives in `StratoHiDriveUtils.psm1` (functions), `StratoHiDriveUtils.psd1` (manifest), and the standalone root-level installer `Install-StratoHiDriveUtils.ps1`.

This file is the maintained rule set for the project. `.github/copilot-instructions.md` and `.github/repo-memory.md` are legacy GitHub Copilot files kept at their standard locations in case the project returns to Copilot; Claude Code does not need to read or update them. `.Test/` and `.vscode/` are gitignored local scratch folders and must not be documented in README.md.

## Validation

There is no test suite or build step. Before finishing work, parse changed files with Windows PowerShell 5.1 (not pwsh) and run PSScriptAnalyzer if installed, fixing any diagnostics the change introduced:

```powershell
powershell.exe -NoProfile -Command "`$e=`$null; [void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path .\StratoHiDriveUtils.psm1), [ref]`$null, [ref]`$e); `$e"
powershell.exe -NoProfile -Command "Invoke-ScriptAnalyzer -Path . -Recurse"
powershell.exe -NoProfile -Command "Import-Module .\StratoHiDriveUtils.psd1 -Force; Get-Command -Module StratoHiDriveUtils"
```

## Release Pipeline

`ModuleVersion` in `StratoHiDriveUtils.psd1` is the single source of truth for the version; never duplicate it in comment-based help. The installer ships inside the release ZIP and is versioned by the manifest, so it carries no version of its own. README.md states the current version under "Versioning"; keep it in sync with the manifest.

Every push to `main` triggers `.github/workflows/create-powershell-release.yml`, which reads `ModuleVersion` via sed (the line format `ModuleVersion = 'x.y.z'` must stay intact), zips all tracked files except `.github/`, `.gitignore`, and `CLAUDE.md` into `StratoHiDriveUtils-<version>.zip`, and publishes GitHub release `v<version>`. The tag must not already exist, so any push to `main` that should succeed needs a version bump. New tooling-only files at the repo root must be added to the `git ls-files` exclusions, otherwise they ship in the module.

Both the installer and `Update-StratoHiDriveUtils` consume that release: they query the GitHub `releases/latest` API, require exactly one asset matching `^StratoHiDriveUtils-x.y.z.zip$`, verify the extracted manifest version matches the asset name, and replace the module folder with a temp backup/rollback. They refuse Git working-tree installations (`.git` present); the updater also refuses duplicate installations across `PSModulePath`. Changing the asset naming, ZIP layout, or manifest format affects all three pieces.

The installer is run via `irm ... | iex` (see README), so it must never call `exit`, which would close the user's session; it signals failure with `throw`.

## Key Behavior

`Get-HiDriveSyncRoot` deliberately avoids reading HiDrive's SQLite `%LOCALAPPDATA%\HiDrive\Data\user.db` (table `User`, field `SyncFolderPath`) to stay dependency-free. It parses `FileSystemSnapshot: Get file system snapshot started. Root <path> |` entries from `%LOCALAPPDATA%\HiDrive\Logs\log.txt` (HiDrive 6.5.x), falling back to legacy `%LOCALAPPDATA%\HiDrive\Data\<digits>.<digits>\syncLog.txt`, and returns `$null` (no exception) when nothing matches.

## Code Rules

- Must parse and run in Windows PowerShell 5.1; no PowerShell 6+ syntax, operators, automatic variables, or cmdlets. Existing code uses tab indentation.
- Each .ps1/.psm1 has exactly one comment-based help block, as the first content (only `#requires` may precede it). No help blocks inside functions; all other comments are single-line `#`.
- Every function gets a concise `#` comment immediately before its definition describing its responsibility and observable behavior.
- Never break a sentence across lines in README.md, comments, or help blocks; new lines only between sentences or list items. All code, comments, output, and docs in English.
- Approved verbs, descriptive names without abbreviations, single-responsibility functions with early returns. No aliases, `Invoke-Expression`, wildcard exports, or global state.
- Use `[CmdletBinding()]`, with `SupportsShouldProcess` for state-changing actions. `Set-StrictMode -Version Latest` is mandatory at script/module scope.
- When adding a public function, update both `FunctionsToExport` in the manifest and `Export-ModuleMember` in the .psm1. Keep `CmdletsToExport`, `VariablesToExport`, `AliasesToExport` explicitly `@()`.
- The module must not log or write log files. Return data/status objects or throw; the importing script decides what to log.
- Validate inputs and paths at boundaries: `Join-Path`, `Test-Path -PathType`, and `-ErrorAction Stop` inside try/catch. Temp files go under `$env:TEMP` and are removed afterward.
- Keep README.md current (structure of user-facing files, prerequisites, usage) and keep its note that AI/KI tooling supported creation of the module. Commit messages describe what changed and why.
