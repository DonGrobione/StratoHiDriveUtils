# Changelog

All notable changes to DonGrobione.StratoHiDriveUtils are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/).
Each version is published as the GitHub release `v<version>` on the [Releases page](https://github.com/DonGrobione/StratoHiDriveUtils/releases).

## [3.1.0] - 2026-09-26

### Added

- `CHANGELOG.md` documents the version history and is part of the release ZIP.
- Pester tests are split into one test file per script: `Tests/DonGrobione.StratoHiDriveUtils.Tests.ps1` and `Tests/Install-StratoHiDriveUtils.Tests.ps1`.

### Changed

- `Start-HiDrive` and `Update-HiDriveUtility` report terminating errors through `$PSCmdlet.ThrowTerminatingError()` with error IDs such as `HiDriveExecutableNotFound`, `HiDriveGitInstallation`, or `HiDriveReleaseVersionMismatch`, so callers can handle failures by `FullyQualifiedErrorId`.
- The license file is renamed from `License.md` to `LICENSE`.

### Removed

- The contact email address in the manifest's `PrivateData.PSData`.

## [3.0.0] - 2026-09-26

### Added

- Pester 5 test suite that GitHub Actions runs before every release.

### Changed

- **Breaking:** `Update-StratoHiDriveUtils` is renamed to `Update-HiDriveUtility` to use a singular noun.
- **Breaking:** Installations use the side-by-side layout `<ModuleBase>\DonGrobione.StratoHiDriveUtils\<ModuleVersion>\` used by `Install-Module`; the installer and the updater migrate flat installations.
- The project is licensed under the GNU Affero General Public License v3.0 (AGPL-3.0).
- The manifest follows PowerShell Gallery publishing best practices, including `FileList`, `CompatiblePSEditions`, and PSData metadata.

## [2.1.0] - 2026-09-26

### Changed

- `Get-HiDriveSyncRoot` writes the non-terminating error `HiDriveSyncRootNotFound` instead of returning `$null` silently.
- `Stop-HiDrive` writes the non-terminating error `HiDriveProcessStopFailed` for each process that cannot be force-stopped.

## [2.0.1] - 2026-09-25

### Fixed

- `Get-HiDriveSyncRoot` finds the sync root with HiDrive 7.x by searching the rotated `syncLog.txt` files.

## [2.0.0] - 2026-09-25

### Changed

- **Breaking:** The module is renamed from `StratoHiDriveUtils` to `DonGrobione.StratoHiDriveUtils`.

## [1.1.6] - 2026-09-13

### Changed

- Installation and update remove old files from the module folder.

## [1.1.5] - 2026-09-13

### Changed

- Internal project files are excluded from the release ZIP.

## [1.1.4] - 2026-09-12

### Added

- `Update-StratoHiDriveUtils` installs the latest GitHub ZIP release.
- `Install-StratoHiDriveUtils.ps1` one-command installer.

## [1.1.3] - 2026-04-20

### Changed

- The release ZIP name contains the manifest version.

## [1.1.2] - 2026-04-20

### Added

- GitHub Actions workflow that publishes a GitHub release for every manifest version.

## [1.1.1] - 2026-04-17

### Changed

- README examples use consistent module import paths.

## [1.1.0] - 2026-04-17

### Added

- `Start-HiDrive` and `Stop-HiDrive` support `-WhatIf` and `-Confirm`.

## [1.0.0] - 2026-04-17

### Added

- Initial release with `Start-HiDrive`, `Stop-HiDrive`, and `Get-HiDriveSyncRoot`.

[3.1.0]: https://github.com/DonGrobione/StratoHiDriveUtils/releases/tag/v3.1.0
[3.0.0]: https://github.com/DonGrobione/StratoHiDriveUtils/releases/tag/v3.0.0
[2.1.0]: https://github.com/DonGrobione/StratoHiDriveUtils/compare/v2.0.1...v3.0.0
[2.0.1]: https://github.com/DonGrobione/StratoHiDriveUtils/releases/tag/v2.0.1
[2.0.0]: https://github.com/DonGrobione/StratoHiDriveUtils/releases/tag/v2.0.0
[1.1.6]: https://github.com/DonGrobione/StratoHiDriveUtils/releases/tag/v1.1.6
[1.1.5]: https://github.com/DonGrobione/StratoHiDriveUtils/releases/tag/v1.1.5
[1.1.4]: https://github.com/DonGrobione/StratoHiDriveUtils/releases/tag/v1.1.4
[1.1.3]: https://github.com/DonGrobione/StratoHiDriveUtils/releases/tag/v1.1.3
[1.1.2]: https://github.com/DonGrobione/StratoHiDriveUtils/releases/tag/v1.1.2
[1.1.1]: https://github.com/DonGrobione/StratoHiDriveUtils/releases/tag/v1.1.1
[1.1.0]: https://github.com/DonGrobione/StratoHiDriveUtils/compare/9565b80...52f4fd7
[1.0.0]: https://github.com/DonGrobione/StratoHiDriveUtils/commit/9565b80
