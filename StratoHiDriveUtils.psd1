@{
    RootModule = 'StratoHiDriveUtils.psm1'
    ModuleVersion = '1.1.1'
    GUID = '3f7a9868-f796-4d67-8f86-b77767531bb4'
    Author = 'DonGrobione'
    CompanyName = 'Independent'
    Copyright = '(c) 2026 DonGrobione. All rights reserved.'
    Description = 'PowerShell module to start/stop STRATO HiDrive and read the sync root from logs.'
    PowerShellVersion = '5.1'

    FunctionsToExport = @(
        'Start-HiDrive'
        'Stop-HiDrive'
        'Get-HiDriveSyncRoot'
    )

    CmdletsToExport = @()
    VariablesToExport = '*'
    AliasesToExport = @()

    PrivateData = @{
        PSData = @{
            Tags = @('PowerShell', 'HiDrive', 'STRATO', 'Utilities')
            ProjectUri = 'https://github.com/DonGrobione/StratoHiDriveUtils'
            LicenseUri = 'https://github.com/DonGrobione/StratoHiDriveUtils/blob/main/License.md'
            Contact = 'dongrobione@proton.me'
        }
    }
}
