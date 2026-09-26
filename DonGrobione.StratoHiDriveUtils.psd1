@{
    RootModule = 'DonGrobione.StratoHiDriveUtils.psm1'
    ModuleVersion = '3.0.0'
    GUID = '3f7a9868-f796-4d67-8f86-b77767531bb4'
    Author = 'DonGrobione'
    CompanyName = 'Independent'
    Copyright = '(c) 2026 DonGrobione. Licensed under the GNU Affero General Public License v3.0 (AGPL-3.0).'
    Description = 'Starts and stops the STRATO HiDrive desktop client, reads its local sync root folder from the HiDrive logs, and updates itself from GitHub releases.'
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop')

    FunctionsToExport = @(
        'Start-HiDrive'
        'Stop-HiDrive'
        'Get-HiDriveSyncRoot'
        'Update-HiDriveUtility'
    )

    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()

    FileList = @(
        'DonGrobione.StratoHiDriveUtils.psd1'
        'DonGrobione.StratoHiDriveUtils.psm1'
        'Install-StratoHiDriveUtils.ps1'
        'License.md'
        'README.md'
    )

    PrivateData = @{
        PSData = @{
            Tags = @('HiDrive', 'STRATO', 'CloudStorage', 'Sync', 'Windows', 'PSEdition_Desktop')
            ProjectUri = 'https://github.com/DonGrobione/StratoHiDriveUtils'
            LicenseUri = 'https://github.com/DonGrobione/StratoHiDriveUtils/blob/main/License.md'
            ReleaseNotes = 'Breaking change: Update-StratoHiDriveUtils was renamed to Update-HiDriveUtility. Reinstall with Install-StratoHiDriveUtils.ps1 when upgrading from 2.x. Full history: https://github.com/DonGrobione/StratoHiDriveUtils/releases'
            Contact = 'dongrobione@proton.me'
        }
    }
}
