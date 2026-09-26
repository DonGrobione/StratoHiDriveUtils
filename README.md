# DonGrobione.StratoHiDriveUtils

PowerShell module for controlling the STRATO HiDrive desktop application and reading the configured sync root directory from HiDrive logs.
This module was primarily created for personal use.

## Project Structure

```text
DonGrobione.StratoHiDriveUtils/
|-- CHANGELOG.md                          # Version history
|-- DonGrobione.StratoHiDriveUtils.psd1   # Module manifest
|-- DonGrobione.StratoHiDriveUtils.psm1   # Main module with exported functions
|-- Install-StratoHiDriveUtils.ps1        # Installer for the latest release, also included in the release ZIP
|-- LICENSE                               # GNU AGPL-3.0 license for this project
|-- README.md                             # This documentation
`-- Tests/                                # Pester tests, not part of the release ZIP
    |-- DonGrobione.StratoHiDriveUtils.Tests.ps1  # Tests for the manifest, packaging, and module functions
    |-- Install-StratoHiDriveUtils.Tests.ps1      # Tests for the installer
    `-- TestHelpers.ps1                           # Shared test fixtures
```

## Module Overview

The module is defined by `DonGrobione.StratoHiDriveUtils.psd1` and loads `DonGrobione.StratoHiDriveUtils.psm1`.
It exports four functions, each with full comment-based help available through `Get-Help`, for example `Get-Help Get-HiDriveSyncRoot -Full`:

- `Start-HiDrive`
- `Stop-HiDrive`
- `Get-HiDriveSyncRoot`
- `Update-HiDriveUtility`

## Requirements

- Windows PowerShell 5.1
- Installed STRATO [HiDrive desktop client](https://static.hidrive.com/windows/0000)
- Read access to `%LOCALAPPDATA%\HiDrive\Logs` and `%LOCALAPPDATA%\HiDrive\Data`

## Installation

### Option 1: One-Command Installer (recommended)

Copy the following single line into Windows PowerShell 5.1.
It downloads and runs the installer directly:

```powershell
irm https://raw.githubusercontent.com/DonGrobione/StratoHiDriveUtils/v3.0.0/Install-StratoHiDriveUtils.ps1 | iex
```

The installer downloads the latest GitHub ZIP release and checks the manifest version before installation.
The release is installed as a versioned module folder at the Windows PowerShell 5.1 user module path, for example `Documents\WindowsPowerShell\Modules\DonGrobione.StratoHiDriveUtils\3.0.0`.
If the current release is already installed in a versioned folder, the installer reports this and makes no changes.
Like `Install-Module`, each version is installed into its own version folder, so a new version never conflicts with an installed one, for example `2.2.0` and `3.0.0` side by side.
An existing valid folder of the release version is reused and never overwritten; if the installation of a new version fails, only its new version folder is removed and existing installations stay untouched.
Afterwards, older versions, flat installations without a version folder, Git installations, and installations under the legacy module name `StratoHiDriveUtils` are removed.
Old installations that cannot be removed, for example in an all-users path without administrator rights, are reported as warnings.

The installer is also part of every release ZIP and therefore of every installed version.
If an update fails, for example across a breaking change, rerun it from the installed module:

```powershell
$module = Get-Module DonGrobione.StratoHiDriveUtils -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
& (Join-Path $module.ModuleBase 'Install-StratoHiDriveUtils.ps1')
```

### Upgrading from Version 2.x

Version 3.0.0 renamed the update command from `Update-StratoHiDriveUtils` to `Update-HiDriveUtility` to follow the PowerShell naming rule for singular nouns.
Versions up to 2.1.0 were also installed without a version folder.
Run the one-command installer once to install 3.0.0 in the versioned layout and remove the 2.x installation.
Scripts that call `Update-StratoHiDriveUtils` must be changed to `Update-HiDriveUtility`.

### Upgrading from Version 1.x

Version 2.0.0 renamed the module from `StratoHiDriveUtils` to `DonGrobione.StratoHiDriveUtils`.
`Update-StratoHiDriveUtils` from version 1.x cannot install the renamed release.
Run the one-command installer once instead; it removes the old `StratoHiDriveUtils` installation and installs the renamed module.
Scripts that import the module by name must be changed to `Import-Module DonGrobione.StratoHiDriveUtils`.

### Option 2: ZIP Download (manual installation)

The latest version is available as a ZIP file on the [Releases page](https://github.com/DonGrobione/StratoHiDriveUtils/releases).

After downloading, extract the ZIP into the appropriate module directory:

| PowerShell Version | Target Directory |
|--------------------|------------------|
| Windows PowerShell 5.1 | `%USERPROFILE%\Documents\WindowsPowerShell\Modules\DonGrobione.StratoHiDriveUtils\<version>` |

> **Note:** The module folder must be named `DonGrobione.StratoHiDriveUtils` and the version folder must match `ModuleVersion` in the manifest, for example `3.0.0`, for PowerShell to auto-discover the module.
> Keep the module in only one `PSModulePath` entry; multiple version folders inside it are supported.

Then load the module:

```powershell
Import-Module DonGrobione.StratoHiDriveUtils -Force
Get-Command -Module DonGrobione.StratoHiDriveUtils
```

---

## Usage

### 1) Start HiDrive

```powershell
Import-Module DonGrobione.StratoHiDriveUtils -Force
Start-HiDrive
```

`Start-HiDrive` checks common install paths and starts `HiDrive.App.exe`.
If no executable is found, the function throws a terminating error with the ID `HiDriveExecutableNotFound`.

### 2) Stop HiDrive

```powershell
Import-Module DonGrobione.StratoHiDriveUtils -Force
Stop-HiDrive
```

`Stop-HiDrive` stops all processes whose name matches `*HiDrive*`.
The function first sends a graceful close request and then force-stops remaining matching processes.
If no process is running, it exits without error.
If a remaining process cannot be force-stopped, the function writes a non-terminating error with the ID `HiDriveProcessStopFailed` for that process and continues with the others.
In practice, `HiDrive.App` and `HiDrive.Sync` are both terminated reliably.

### 3) Read Sync Root Directory

```powershell
Import-Module DonGrobione.StratoHiDriveUtils -Force
Get-HiDriveSyncRoot
```

This returns the sync root path directly (string), for example:

```text
C:\Users\<User>\HiDrive
```

If no matching log entry is found, the function writes a non-terminating error with the ID `HiDriveSyncRootNotFound` and returns no output.
The error message names the searched log folders and any log locations that could not be read.
The module never logs by itself, so the calling script decides how to handle and log the error.
Use `-ErrorAction Stop` with `try`/`catch` to detect a failed lookup, because an `-ErrorVariable` can also collect read errors of individual log files that the function already handled internally:

```powershell
Import-Module DonGrobione.StratoHiDriveUtils -Force
try {
    $syncRoot = Get-HiDriveSyncRoot -ErrorAction Stop
    "Sync root: $syncRoot"
} catch {
    "Sync root lookup failed: $($_.Exception.Message)"
}
```

### 4) Update from the ZIP Release

`Update-HiDriveUtility` checks the latest GitHub release and installs it as a new version folder next to the currently loaded version, following the PowerShell side-by-side module layout.
Like `Update-Module`, the new version is installed into its own version folder, so it never conflicts with the loaded version.
An existing valid folder of the release version is reused and never overwritten; if the installation fails, only the new version folder is removed and the loaded version stays untouched.
After a successful update, older version folders and flat installation files without a version folder are removed; newer version folders are kept.
Old items that cannot be removed are listed in the `FailedRemovals` property of the returned status object and reported as a warning.
The module must be located in the current PowerShell version's `PSModulePath` and exist in only one of its entries.
Existing Git installations must be replaced with the ZIP release first by running the installer; the update command does not overwrite a Git working tree.
Failures are terminating errors with IDs that start with `HiDrive`, for example `HiDriveGitInstallation`, `HiDriveDuplicateInstallation`, or `HiDriveReleaseVersionMismatch`, so scripts can check `$_.FullyQualifiedErrorId` in a `catch` block.
If the update fails, reinstall the module with the installer as described under Installation.

```powershell
Import-Module DonGrobione.StratoHiDriveUtils -Force
Update-HiDriveUtility
```

To check the available version without changing anything, use `-WhatIf`:

```powershell
Update-HiDriveUtility -WhatIf
```

After a successful update, reload the module:

```powershell
Remove-Module DonGrobione.StratoHiDriveUtils -Force -ErrorAction SilentlyContinue
Import-Module DonGrobione.StratoHiDriveUtils -Force
```

## Log Search Behavior in `Get-HiDriveSyncRoot`

The sync root is actually stored by HiDrive in the SQLite database `%LOCALAPPDATA%\HiDrive\Data\user.db`.
In practice, reading that value requires additional SQLite software or editor extensions.
To keep this module dependency-free, `Get-HiDriveSyncRoot` reads the sync root from HiDrive log entries instead.

The function searches these log files, including their rotated copies such as `log.0.txt` or `syncLog.0.txt`:

- Application logs: `%LOCALAPPDATA%\HiDrive\Logs\log.txt` (HiDrive 6.5.x)
- Sync logs: `%LOCALAPPDATA%\HiDrive\Data\<numeric folder>\syncLog.txt` (older versions and HiDrive 7.x)

Files are searched from the most recently written to the oldest, and the last matching entry of the first file with a match is returned.
It extracts entries matching:

- `FileSystemSnapshot: Get file system snapshot started. Root <path> |`
- `FSW: started for root <path> |`

## Troubleshooting

- `Start-HiDrive` fails:
  - Verify STRATO HiDrive is installed.
  - Verify one of these files exists:
    - `%ProgramFiles%\STRATO\HiDrive\HiDrive.App.exe`
    - `%ProgramFiles(x86)%\STRATO\HiDrive\HiDrive.App.exe`
    - `%LOCALAPPDATA%\STRATO\HiDrive\HiDrive.App.exe`
- `Get-HiDriveSyncRoot` reports `HiDriveSyncRootNotFound`:
  - HiDrive may not have completed an initial scan yet.
  - Check whether log files exist under `%LOCALAPPDATA%\HiDrive\Logs` or `%LOCALAPPDATA%\HiDrive\Data\<numeric folder>`.
  - Start HiDrive once and allow it to run briefly before trying again.

## Versioning

- Module version source of truth: `DonGrobione.StratoHiDriveUtils.psd1` (`ModuleVersion`).
- Current manifest version: `3.1.0`.
- The module file `DonGrobione.StratoHiDriveUtils.psm1` does not duplicate module version metadata.
- Versions follow Semantic Versioning: the major version increases for breaking changes such as renamed functions or a changed installation layout, the minor version for new features, and the patch version for fixes.
- Every release ZIP contains the files listed in `FileList` of the manifest, including `Install-StratoHiDriveUtils.ps1`.
- `CHANGELOG.md` lists the changes of every version, and `ReleaseNotes` in the manifest summarizes the current version.

### Tests

The Pester 5 tests in `Tests/` check the manifest, the release packaging, the project documents, code quality with PSScriptAnalyzer, the comment-based help, all exported functions, and the installer.
Each script has its own test file named `Tests/<ScriptName>.Tests.ps1`.
They run in isolated `TestDrive` folders with mocked GitHub calls and never change real installations.
Run them in Windows PowerShell 5.1 from the repository root:

```powershell
Install-Module -Name Pester -MinimumVersion 5.5.0 -MaximumVersion 5.99.99 -Scope CurrentUser -SkipPublisherCheck
Install-Module -Name PSScriptAnalyzer -Scope CurrentUser
Invoke-Pester -Path .\Tests -Output Detailed
```

GitHub Actions runs the same tests for pull requests and for pushes to other branches, and before every release.

### Create a New Release

1. Update `ModuleVersion` and `ReleaseNotes` in `DonGrobione.StratoHiDriveUtils.psd1`, for example from `2.0.0` to `2.0.1`.
2. Add a section for the new version at the top of `CHANGELOG.md` and update the current version under Versioning in this README.
3. Commit the changes and merge them into `main`.
4. Push `main` to GitHub.

The GitHub Actions workflow runs automatically when `main` is updated.
It first runs the Pester tests and stops without a release if any test fails.
It then reads the manifest version, creates `DonGrobione.StratoHiDriveUtils-<version>.zip`, creates the GitHub tag `v<version>`, and publishes the GitHub Release with the ZIP attached.
The tag must not already exist.
For version `2.0.0`, the workflow creates tag `v2.0.0` and release file `DonGrobione.StratoHiDriveUtils-2.0.0.zip`.

## License

This project is licensed under the GNU Affero General Public License v3.0 (AGPL-3.0).
See `LICENSE` for the full license text.

## Disclaimer

I am in no way affiliated with STRATO or HiDrive.
This project is an independent, unofficial utility module and is not endorsed by, sponsored by, or connected to STRATO/HiDrive.

## AI Usage

This project was created with support from AI/KI tooling.
