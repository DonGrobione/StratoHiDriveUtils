<#
.SYNOPSIS
Shared Pester fixtures for the DonGrobione.StratoHiDriveUtils test files.

.DESCRIPTION
Defines the repository paths, the manifest data, and helper functions that build test installations and release ZIPs in the Pester TestDrive.
Dot-source this file in the BeforeAll block of a test file; it makes no changes outside the TestDrive.

.EXAMPLE
BeforeAll { . (Join-Path $PSScriptRoot 'TestHelpers.ps1') }

Loads the shared fixtures into a Pester test file.
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'The variables are used by the test files that dot-source this file.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helpers only create fixtures in the Pester TestDrive.')]
param()

Set-StrictMode -Version Latest

$script:moduleName = 'DonGrobione.StratoHiDriveUtils'
$script:repositoryRoot = Split-Path -Path $PSScriptRoot -Parent
$script:manifestPath = Join-Path $script:repositoryRoot "$script:moduleName.psd1"
$script:installerPath = Join-Path $script:repositoryRoot 'Install-StratoHiDriveUtils.ps1'
$script:manifestData = Import-PowerShellDataFile -LiteralPath $script:manifestPath
$script:releaseVersion = [version]$script:manifestData.ModuleVersion
$script:projectUri = $script:manifestData.PrivateData.PSData.ProjectUri

# Returns the tracked files that the release workflow packs into the ZIP, using the exclusions from the workflow itself.
function Get-ShippedFile {
	$workflow = Get-Content -LiteralPath (Join-Path $script:repositoryRoot '.github\workflows\create-powershell-release.yml') -Raw
	$command = [regex]::Match($workflow, 'git ls-files (?<Arguments>[^>]+)>').Groups['Arguments'].Value
	$exclusions = @([regex]::Matches($command, "'(?<Pathspec>[^']+)'") | ForEach-Object { $_.Groups['Pathspec'].Value })
	Push-Location -LiteralPath $script:repositoryRoot
	try {
		@(git ls-files @exclusions | Sort-Object)
	}
	finally {
		Pop-Location
	}
}

# Copies the shipped module files into a folder and sets the manifest version, simulating an installed release.
function New-TestInstallation {
	param(
		[string]$Path,
		[string]$Version
	)

	New-Item -ItemType Directory -Path $Path -Force | Out-Null
	foreach ($file in $script:manifestData.FileList) {
		Copy-Item -LiteralPath (Join-Path $script:repositoryRoot $file) -Destination $Path
	}
	$installedManifest = Join-Path $Path "$script:moduleName.psd1"
	(Get-Content -LiteralPath $installedManifest -Raw) -replace "ModuleVersion = '[^']+'", "ModuleVersion = '$Version'" |
		Set-Content -LiteralPath $installedManifest -Encoding UTF8
}

# Builds a release ZIP from the shipped module files with the given manifest version.
function New-TestReleaseZip {
	param(
		[string]$Path,
		[string]$ManifestVersion
	)

	$sourcePath = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
	New-TestInstallation -Path $sourcePath -Version $ManifestVersion
	Compress-Archive -Path (Join-Path $sourcePath '*') -DestinationPath $Path
}

# Returns a fake GitHub releases/latest response for the current release version.
function Get-TestRelease {
	[pscustomobject]@{
		assets = @(
			[pscustomobject]@{
				name = "$script:moduleName-$script:releaseVersion.zip"
				browser_download_url = 'https://example.invalid/release.zip'
			}
		)
	}
}
