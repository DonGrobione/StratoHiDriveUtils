# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

DonGrobione.StratoHiDriveUtils is a small, dependency-free Windows PowerShell 5.1 module for controlling the STRATO HiDrive desktop client: `Start-HiDrive`, `Stop-HiDrive`, `Get-HiDriveSyncRoot`, and the self-updater `Update-StratoHiDriveUtils`. All code lives in `DonGrobione.StratoHiDriveUtils.psm1` (functions), `DonGrobione.StratoHiDriveUtils.psd1` (manifest), and the standalone root-level installer `Install-StratoHiDriveUtils.ps1`.

The module was renamed from `StratoHiDriveUtils` in 2.0.0 to follow the `Company.Product` naming convention. The GitHub repository, the function names, and the installer file name deliberately keep the old name. The installer detects and replaces installations under the legacy name; 1.x `Update-StratoHiDriveUtils` cannot reach 2.x releases, so users migrate by rerunning the installer. The module folder name must equal the module name (`DonGrobione.StratoHiDriveUtils`) for auto-discovery.

This file is the only rule set for the project; the former GitHub Copilot rules and repository memory were merged into it. The goal is compliance with Microsoft and PowerShell module-authoring best practices. `.github/` holds only standard GitHub files such as workflows. `.Test/` and `.vscode/` are gitignored local scratch folders and must not be documented in README.md.

## Validation

There is no test suite or build step. Before finishing work, parse changed files with Windows PowerShell 5.1 (not pwsh) and run PSScriptAnalyzer if installed, fixing any diagnostics the change introduced:

```powershell
powershell.exe -NoProfile -Command "`$e=`$null; [void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path .\DonGrobione.StratoHiDriveUtils.psm1), [ref]`$null, [ref]`$e); `$e"
powershell.exe -NoProfile -Command "Invoke-ScriptAnalyzer -Path . -Recurse"
powershell.exe -NoProfile -Command "Import-Module .\DonGrobione.StratoHiDriveUtils.psd1 -Force; Get-Command -Module DonGrobione.StratoHiDriveUtils"
```

## Release Pipeline

`ModuleVersion` in `DonGrobione.StratoHiDriveUtils.psd1` is the single source of truth for the version; never duplicate it in comment-based help. The installer ships inside the release ZIP and is versioned by the manifest, so it carries no version of its own. README.md states the current version under "Versioning"; keep it in sync with the manifest.

Every push to `main` triggers `.github/workflows/create-powershell-release.yml`, which reads `ModuleVersion` via sed (the line format `ModuleVersion = 'x.y.z'` must stay intact), zips all tracked files except `.github/`, `.gitignore`, and `CLAUDE.md` into `DonGrobione.StratoHiDriveUtils-<version>.zip`, and publishes GitHub release `v<version>`. The tag must not already exist, so any push to `main` that should succeed needs a version bump. New tooling-only files at the repo root must be added to the `git ls-files` exclusions, otherwise they ship in the module.

Both the installer and `Update-StratoHiDriveUtils` consume that release: they query the GitHub `releases/latest` API, require exactly one asset matching `^DonGrobione\.StratoHiDriveUtils-x.y.z.zip$` (the module name is regex-escaped), verify the extracted manifest version matches the asset name, and replace the module folder with a temp backup/rollback. They refuse Git working-tree installations (`.git` present); the updater also refuses duplicate installations across `PSModulePath`. Changing the asset naming, ZIP layout, or manifest format affects all three pieces.

The installer is run via `irm ... | iex` from a URL pinned to a release tag in README.md (update that tag when the installer changes), so it must never call `exit`, which would close the user's session; it signals failure with `throw`.

## Key Behavior

`Get-HiDriveSyncRoot` deliberately avoids reading HiDrive's SQLite `%LOCALAPPDATA%\HiDrive\Data\user.db` (table `User`, field `SyncFolderPath`) to stay dependency-free. It parses `FileSystemSnapshot: Get file system snapshot started. Root <path> |` entries from HiDrive logs and returns `$null` (no exception) when nothing matches:

- HiDrive 6.5.x writes rotating logs `log.txt`, `log.0.txt`, and so on under `%LOCALAPPDATA%\HiDrive\Logs\`; the primary target is `log.txt`.
- Older HiDrive versions wrote `syncLog.txt` into subfolders of `%LOCALAPPDATA%\HiDrive\Data\` matching `^\d+\.\d+$` (for example `52794237.1`); these are the fallback.

## Code Rules

- Must parse and run in Windows PowerShell 5.1; no PowerShell 6+ syntax, operators, automatic variables, or cmdlets. Existing code uses tab indentation.
- Standalone installer scripts live at the project root.
- Each .ps1/.psm1 has exactly one comment-based help block, as the first content (only `#requires` may precede it). No help blocks inside functions; all other comments are single-line `#`.
- Every function gets a concise `#` comment immediately before its definition describing its responsibility and observable behavior.
- Never break a sentence across lines in README.md, comments, or help blocks; new lines only between sentences or list items. All code, comments, help, output, log messages, and docs in English.
- Approved verbs (verify with `Get-Verb`) and descriptive PascalCase/camelCase names without abbreviations, except loop counters. Single-responsibility, action-oriented functions with early returns. No aliases, `Invoke-Expression`, wildcard exports, global state, or unnecessary side effects.
- Use `[CmdletBinding()]`, with `SupportsShouldProcess` for state-changing or destructive actions. `Set-StrictMode -Version Latest` is mandatory at script/module scope.
- When adding a public function, update both `FunctionsToExport` in the manifest and `Export-ModuleMember` in the .psm1. Keep `CmdletsToExport`, `VariablesToExport`, `AliasesToExport` explicitly `@()`.
- Validate inputs and paths at boundaries: `Join-Path`, `Test-Path -PathType`, and `-ErrorAction Stop` inside try/catch. Temp files go under `$env:TEMP` and are removed afterward.
- Keep README.md current (project structure, purpose of every user-facing file and directory, prerequisites, configuration, usage) and keep its note that AI/KI tooling supported creation of the module. After code changes, verify that examples, file structure, and guidelines still match the codebase. Commit messages describe what changed and why.
- Standalone .ps1 scripts without a manifest carry a version number in their help block and keep it current when behavior changes; scripts shipped in the module's release ZIP (the installer) use the manifest version instead.

## Logging, Errors, and Security

- The module must not log or write log files. It returns data, status objects, or error records, or throws; the importing script decides what to log.
- If an orchestrator or entry-point script is added, only a `Write-Log.psm1` module writes logs, and only the orchestrator calls it. Each log entry is prefixed with the emitting script name (for example `[MyScript.ps1]`), project paths are logged relative to the repo root and `$env:TEMP` paths absolutely, and errors already logged are not logged again.
- Child scripts catch their own errors and rethrow so failures reach the orchestrator. Entry points exit with 0 on success and 1 on unhandled failure, except scripts run via `irm | iex`, which throw instead.
- Treat all input as untrusted; apply defense in depth, least privilege, and fail-secure behavior. Secrets are never stored in code; read them at runtime from a .psd1 file under `Secrets/` and never log their values.
