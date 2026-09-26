# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

DonGrobione.StratoHiDriveUtils is a small, dependency-free Windows PowerShell 5.1 module for controlling the STRATO HiDrive desktop client: `Start-HiDrive`, `Stop-HiDrive`, `Get-HiDriveSyncRoot`, and the self-updater `Update-HiDriveUtility`. All code lives in `DonGrobione.StratoHiDriveUtils.psm1` (functions), `DonGrobione.StratoHiDriveUtils.psd1` (manifest), and the standalone root-level installer `Install-StratoHiDriveUtils.ps1`, which also ships inside the release ZIP. The project is licensed under the GNU Affero General Public License v3.0 (AGPL-3.0, `LICENSE`). `README.md`, `LICENSE`, and `CHANGELOG.md` live at the project root and ship in the release ZIP.

The module was renamed from `StratoHiDriveUtils` in 2.0.0 to follow the `Company.Product` naming convention; the GitHub repository and the installer file name deliberately keep the old name. In 3.0.0 the self-updater was renamed from `Update-StratoHiDriveUtils` to `Update-HiDriveUtility` to use a singular noun. Breaking changes are acceptable when they bring the module in line with PowerShell best practices; users of affected versions reinstall with the installer script, and README.md documents that migration.

Installations use the side-by-side layout `<ModuleBase>\DonGrobione.StratoHiDriveUtils\<ModuleVersion>\` used by `Install-Module`; the module folder name must equal the module name and the version folder must equal `ModuleVersion` for auto-discovery. Releases up to 2.1.0 used a flat layout without a version folder, which the installer and updater migrate.

This file is the only rule set for the project. The goal is compliance with Microsoft PowerShell module-authoring guidelines and PowerShell Gallery publishing requirements, even though the module is distributed through GitHub releases and not the Gallery, so it can be published to the Gallery later without restructuring. `.github/` holds only standard GitHub files such as workflows. `.Test/` and `.vscode/` are gitignored local scratch folders and must not be documented in README.md.

## Validation

There is no build step. `Tests/` holds the Pester 5 test suite with one test file per script, named `Tests/<ScriptName>.Tests.ps1`: `DonGrobione.StratoHiDriveUtils.Tests.ps1` covers the manifest and `FileList` against the release workflow's shipped files, the project documents, parsing, PSScriptAnalyzer, comment-based help, and every exported function, and `Install-StratoHiDriveUtils.Tests.ps1` covers the installer. Shared fixtures live in `Tests/TestHelpers.ps1`, which the test files dot-source in `BeforeAll`. The tests run in Windows PowerShell 5.1 using `TestDrive` sandboxes and mocked GitHub calls, and must never touch real installations, the real `PSModulePath`, or the network.

The suite deliberately uses Pester 5 syntax (`Should -Be`), not the Pester 4 syntax (`Should Be`), because Pester 5 no longer supports the legacy syntax and CI installs Pester 5. A new script or function gets tests in its script's test file, and a new script gets its own `Tests/<ScriptName>.Tests.ps1`. A modified script or function gets updated tests that cover the change. After any creation or modification, run the affected test files, for example `Invoke-Pester -Path .\Tests\Install-StratoHiDriveUtils.Tests.ps1`, report the results to the user, and fix the code or the tests before considering the task complete. Before finishing work, run the full suite and these checks with Windows PowerShell 5.1 (not pwsh). The manifest must pass `Test-ModuleManifest`, every file must parse, and PSScriptAnalyzer must report no findings of any severity, as required for PowerShell Gallery publishing:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -MinimumVersion 5.5.0 -MaximumVersion 5.99.99; Invoke-Pester -Path .\Tests -Output Detailed"
powershell.exe -NoProfile -Command "foreach (`$f in '.\DonGrobione.StratoHiDriveUtils.psm1', '.\Install-StratoHiDriveUtils.ps1') { `$e = `$null; [void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path `$f), [ref]`$null, [ref]`$e); `$e }"
powershell.exe -NoProfile -Command "Test-ModuleManifest .\DonGrobione.StratoHiDriveUtils.psd1"
powershell.exe -NoProfile -Command "Invoke-ScriptAnalyzer -Path . -Recurse"
powershell.exe -NoProfile -Command "Import-Module .\DonGrobione.StratoHiDriveUtils.psd1 -Force; Get-Command -Module DonGrobione.StratoHiDriveUtils; Get-Help Update-HiDriveUtility -Full"
```

## Versioning and Release Pipeline

`ModuleVersion` in `DonGrobione.StratoHiDriveUtils.psd1` is the single source of truth for the version; never duplicate it in comment-based help. It follows Semantic Versioning: MAJOR for breaking changes (a removed or renamed exported function, changed parameters, changed output, or a changed installation layout), MINOR for backward-compatible features, PATCH for fixes. The installer ships inside the release ZIP and is versioned by the manifest, so it carries no version of its own. README.md states the current version under "Versioning"; keep it in sync with the manifest. Every release-relevant change bumps `ModuleVersion`, replaces `ReleaseNotes` in the manifest with a summary that starts with `<version>:`, and adds a Keep a Changelog section `## [<version>] - <yyyy-MM-dd>` at the top of `CHANGELOG.md`; the tests check all three.

`.github/workflows/test-powershell-module.yml` runs the Pester suite on `windows-latest` with Windows PowerShell 5.1, Pester 5, and PSScriptAnalyzer for pull requests and pushes to other branches. Every push to `main` triggers `.github/workflows/create-powershell-release.yml`, which first calls the test workflow and publishes nothing if it fails, then reads `ModuleVersion` via sed (the line format `ModuleVersion = 'x.y.z'` must stay intact), zips all tracked files except `.github/`, `.gitignore`, `CLAUDE.md`, and `Tests/` into `DonGrobione.StratoHiDriveUtils-<version>.zip` with the manifest at the ZIP root, and publishes GitHub release `v<version>`. The tag must not already exist, so any push to `main` that should succeed needs a version bump. New tooling-only files at the repo root must be added to the `git ls-files` exclusions, otherwise they ship in the module. Every shipped file, including `Install-StratoHiDriveUtils.ps1`, must be listed in the manifest's `FileList`, and `FileList` must not list anything that is not shipped.

Both the installer and `Update-HiDriveUtility` consume that release: they query the GitHub `releases/latest` API, require exactly one asset matching `^DonGrobione\.StratoHiDriveUtils-x.y.z.zip$` (the module name is regex-escaped), verify the extracted manifest version matches the asset name, install the release directly into its own version folder like `Install-Module` (no staging or hidden folders; an existing valid folder of that version is reused and never overwritten, and only a version folder created by the failing run is removed on error), and only then remove old installations. Failed removals of old installations are warnings, not failures. The updater removes older version folders and flat files in its own module root but keeps newer versions; the installer removes every other installation, including Git working trees and the legacy name. The updater refuses Git working-tree installations (`.git` present) and module folders in more than one `PSModulePath` entry. Changing the asset naming, ZIP layout, or manifest format affects all three pieces.

The installer is run via `irm ... | iex` from a URL pinned to a release tag in README.md (update that tag when the installer changes), so it must never call `exit`, which would close the user's session; it signals failure with `throw`. Under `iex`, `$PSCmdlet` does not exist while parameters such as `$Force` keep their defaults, so the installer reads `$PSCmdlet` only through `Get-Variable`.

## Key Behavior

`Get-HiDriveSyncRoot` deliberately avoids reading HiDrive's SQLite `%LOCALAPPDATA%\HiDrive\Data\user.db` (table `User`, field `SyncFolderPath`) to stay dependency-free. It parses `FileSystemSnapshot: Get file system snapshot started. Root <path> |` or `FSW: started for root <path> |` entries from HiDrive logs, searching all candidate files newest first by LastWriteTime, and writes a non-terminating `HiDriveSyncRootNotFound` error (no output, no exception unless the caller sets `-ErrorAction Stop`) when nothing matches, listing any unreadable log locations in the message:

- HiDrive 6.5.x writes the snapshot entry to rotating logs `log.txt`, `log.0.txt`, and so on under `%LOCALAPPDATA%\HiDrive\Logs\`.
- Older versions and HiDrive 7.x write it to rotating logs `syncLog.txt`, `syncLog.0.txt`, and so on in subfolders of `%LOCALAPPDATA%\HiDrive\Data\` matching `^\d+\.\d+$` (for example `52794237.1`); HiDrive 7.x no longer writes it to `Logs\log.txt`.
- Rotation means the current file often has no match, so rotated files must always be searched.

## Module Manifest

- The manifest defines `RootModule`, `ModuleVersion`, `GUID` (never changes), `Author = 'DonGrobione'`, `CompanyName`, `Copyright` (naming the AGPL-3.0 license), `Description`, `PowerShellVersion = '5.1'`, `CompatiblePSEditions = @('Desktop')`, and `FileList`.
- `FunctionsToExport` lists every public function explicitly and matches `Export-ModuleMember` in the .psm1; `CmdletsToExport`, `VariablesToExport`, and `AliasesToExport` stay explicitly `@()`. Never use wildcards.
- `PrivateData.PSData` contains `Tags` (no spaces, including `Windows` and `PSEdition_Desktop`), `ProjectUri`, `LicenseUri`, and `ReleaseNotes`. `ProjectUri` is the actual GitHub repository URL `https://github.com/DonGrobione/StratoHiDriveUtils`, and `LicenseUri` is its blob URL of `LICENSE` on `main`. Never invent placeholder URLs; a project that is not yet on GitHub leaves both empty.
- Do not add an email address anywhere unless it is explicitly required, including the manifest, code, help, and docs; the tests reject email addresses in shipped files.

## Code Rules

- Must parse and run in Windows PowerShell 5.1; no PowerShell 6+ syntax, operators, automatic variables, or cmdlets. Existing code uses tab indentation.
- Standalone installer scripts live at the project root.
- Every exported function has complete comment-based help as the first content inside the function body: `.SYNOPSIS`, `.DESCRIPTION`, one `.PARAMETER` per parameter, at least one `.EXAMPLE`, `.INPUTS`, `.OUTPUTS`, and `.LINK` to the project page. Private helper functions get a concise `#` comment immediately before their definition instead.
- The .psm1 has no file-level help block, because `Get-Help` does not use it; the module overview lives in README.md. Each .ps1 script has exactly one comment-based help block as its first content (only `#requires` may precede it). All other comments are single-line `#`.
- Never break a sentence across lines in README.md, comments, or help blocks; new lines only between sentences or list items. All code, comments, help, output, log messages, and docs in English.
- Approved verbs (verify with `Get-Verb`) and singular nouns with the shared `HiDrive` noun prefix for public functions. Descriptive PascalCase/camelCase names without abbreviations, except loop counters. Single-responsibility, action-oriented functions with early returns. No aliases, `Invoke-Expression`, wildcard exports, global state, or unnecessary side effects.
- Use `[CmdletBinding()]` and `[OutputType()]` on every function, with `SupportsShouldProcess` and a fitting `ConfirmImpact` for state-changing or destructive actions, and guard every state change with `$PSCmdlet.ShouldProcess()`. Declare every parameter with a `[Parameter()]` attribute and validation attributes such as `[ValidateNotNullOrEmpty()]`, `[ValidateSet()]`, or `[ValidatePattern()]` where the input allows it. `Set-StrictMode -Version Latest` is mandatory at script/module scope.
- Functions return objects, not formatted text, and never use `Write-Host`. Use `Write-Error` with an `-ErrorId` for non-terminating errors, `Write-Warning` for completed operations with partial problems, and `Write-Verbose` for diagnostic detail.
- Exported functions report terminating errors through `$PSCmdlet.ThrowTerminatingError()` with an ErrorRecord from the private helper `ConvertTo-ErrorRecord` and an error ID that starts with `HiDrive`, and document these IDs in their help and README.md. A `throw` inside an exported function is allowed only within a `try` statement whose `catch` passes the error to `$PSCmdlet.ThrowTerminatingError($_)`; the tests enforce this. The installer uses `throw`, because `$PSCmdlet` does not exist under `iex`.
- No hard-coded secrets or machine-specific paths; derive paths from environment variables such as `$env:LOCALAPPDATA` or from `$PSScriptRoot`.
- When adding a public function, update `FunctionsToExport` in the manifest, `Export-ModuleMember` in the .psm1, and README.md.
- Validate inputs and paths at boundaries: `Join-Path`, `Test-Path -PathType`, and `-ErrorAction Stop` inside try/catch. Temp files go under `$env:TEMP` and are removed afterward.
- Keep README.md current (project structure, purpose of every user-facing file and directory, prerequisites, configuration, usage, license) and keep its note that AI/KI tooling supported creation of the module. After code changes, verify that examples, file structure, and guidelines still match the codebase. Commit messages describe what changed and why.
- Standalone .ps1 scripts without a manifest carry a version number in their help block and keep it current when behavior changes; scripts shipped in the module's release ZIP (the installer) use the manifest version instead.

## Logging, Errors, and Security

- The module must not log or write log files. It returns data, status objects, or error records, or throws; the importing script decides what to log.
- If an orchestrator or entry-point script is added, only a `Write-Log.psm1` module writes logs, and only the orchestrator calls it. Each log entry is prefixed with the emitting script name (for example `[MyScript.ps1]`), project paths are logged relative to the repo root and `$env:TEMP` paths absolutely, and errors already logged are not logged again.
- Child scripts catch their own errors and rethrow so failures reach the orchestrator. Entry points exit with 0 on success and 1 on unhandled failure, except scripts run via `irm | iex`, which throw instead.
- Treat all input as untrusted; apply defense in depth, least privilege, and fail-secure behavior. Secrets are never stored in code; read them at runtime from a .psd1 file under `Secrets/` and never log their values.
