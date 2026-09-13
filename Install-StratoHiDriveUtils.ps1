<#
.SYNOPSIS
Installs or updates StratoHiDriveUtils from the latest GitHub ZIP release.

.DESCRIPTION
Checks the latest GitHub release, detects existing module installations in the current Windows PowerShell 5.1 PSModulePath, and installs the release in the current user's Windows PowerShell module directory.
An existing ZIP installation with the current version is left unchanged.
Older installations and Git working trees are replaced.

.PARAMETER Force
Suppresses the confirmation prompt for replacing an existing installation.

.EXAMPLE
.\Install-StratoHiDriveUtils.ps1 -Force

Installs or updates StratoHiDriveUtils without prompting.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
	[switch]$Force
)

Set-StrictMode -Version Latest

$moduleName = 'StratoHiDriveUtils'
$repositoryName = 'DonGrobione/StratoHiDriveUtils'
$temporaryRoot = $null
$backupRoot = $null

try {
	$release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repositoryName/releases/latest" -Headers @{
		Accept = 'application/vnd.github+json'
		'User-Agent' = $moduleName
		'X-GitHub-Api-Version' = '2022-11-28'
	} -Method Get -ErrorAction Stop

	$releaseAssets = @($release.assets | Where-Object { $_.name -match "^$moduleName-[0-9]+\.[0-9]+\.[0-9]+\.zip$" })
	if ($releaseAssets.Count -ne 1) {
		throw 'The latest GitHub release does not contain exactly one valid module ZIP asset.'
	}

	$releaseVersion = [version]($releaseAssets[0].name -replace "^$moduleName-|\.zip$")
	$pathEntries = @($env:PSModulePath -split [System.IO.Path]::PathSeparator | Where-Object { $_ })
	$moduleCandidates = foreach ($pathEntry in $pathEntries) {
		$candidatePath = Join-Path $pathEntry $moduleName
		$candidateManifest = Join-Path $candidatePath "$moduleName.psd1"
		if (Test-Path -LiteralPath $candidateManifest -PathType Leaf) {
			$manifestData = Import-PowerShellDataFile -LiteralPath $candidateManifest
			[pscustomobject]@{
				Path = [System.IO.Path]::GetFullPath($candidatePath)
				Version = [version]$manifestData.ModuleVersion
				IsGit = Test-Path -LiteralPath (Join-Path $candidatePath '.git')
			}
		}
	}
	$moduleCandidates = @($moduleCandidates | Sort-Object Path -Unique)

	$validCurrentInstallations = @($moduleCandidates | Where-Object { $_.Version -eq $releaseVersion -and -not $_.IsGit })
	if ($moduleCandidates.Count -eq 1 -and $validCurrentInstallations.Count -eq 1) {
		Write-Output "StratoHiDriveUtils $releaseVersion is already installed at '$($validCurrentInstallations[0].Path)'. No changes were made."
		return
	}

	$userDocuments = [Environment]::GetFolderPath('MyDocuments')
	if ([string]::IsNullOrWhiteSpace($userDocuments)) {
		$userDocuments = Join-Path $HOME 'Documents'
	}
	$userModuleBase = Join-Path $userDocuments 'WindowsPowerShell\Modules'
	$targetPath = Join-Path $userModuleBase $moduleName
	$targetParent = [System.IO.Path]::GetFullPath($userModuleBase)
	$knownModuleBases = @($pathEntries | ForEach-Object { [System.IO.Path]::GetFullPath($_) })
	if ($knownModuleBases -notcontains $targetParent) {
		throw "The target module directory '$targetParent' is not part of the current PSModulePath."
	}

	$action = "Replace existing StratoHiDriveUtils installations with release $releaseVersion at '$targetPath'"
	$shouldInstall = $false
	$forceValue = Get-Variable -Name Force -ValueOnly -ErrorAction SilentlyContinue
	$whatIfValue = Get-Variable -Name WhatIfPreference -ValueOnly -ErrorAction SilentlyContinue
	$cmdletValue = Get-Variable -Name PSCmdlet -ValueOnly -ErrorAction SilentlyContinue
	if ($whatIfValue) {
		$shouldInstall = $false
	} elseif ($forceValue) {
		$shouldInstall = $true
	} elseif ($null -ne $cmdletValue -and $cmdletValue.ShouldProcess($targetPath, $action)) {
		$shouldInstall = $true
	} elseif ($null -eq $cmdletValue) {
		$shouldInstall = $true
	}
	if (-not $shouldInstall) {
		Write-Output "StratoHiDriveUtils $releaseVersion is available. No changes were made."
		return
	}

	$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) "$moduleName-installer-$([guid]::NewGuid().ToString('N'))"
	$backupRoot = Join-Path $temporaryRoot 'Backups'
	$zipPath = Join-Path $temporaryRoot $releaseAssets[0].name
	$extractPath = Join-Path $temporaryRoot 'Extracted'
	New-Item -ItemType Directory -Path $temporaryRoot, $backupRoot -Force -ErrorAction Stop | Out-Null
	Invoke-WebRequest -Uri $releaseAssets[0].browser_download_url -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
	Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force -ErrorAction Stop

	$packageManifests = @(Get-ChildItem -LiteralPath $extractPath -Filter "$moduleName.psd1" -File -Recurse -ErrorAction Stop)
	if ($packageManifests.Count -ne 1) {
		throw 'The downloaded ZIP does not contain exactly one valid module manifest.'
	}
	$packageRoot = $packageManifests[0].Directory.FullName
	$packageData = Import-PowerShellDataFile -LiteralPath $packageManifests[0].FullName
	$packageVersion = [version]$packageData.ModuleVersion
	if ($packageVersion -ne $releaseVersion) {
		throw "The ZIP asset version $releaseVersion does not match the manifest version $packageVersion."
	}

	$backups = @()
	foreach ($candidate in $moduleCandidates) {
		$backupPath = Join-Path $backupRoot ([guid]::NewGuid().ToString('N'))
		Copy-Item -LiteralPath $candidate.Path -Destination $backupPath -Recurse -Force -ErrorAction Stop
		$backups += [pscustomobject]@{ OriginalPath = $candidate.Path; BackupPath = $backupPath }
	}

	Get-Module -Name $moduleName | Remove-Module -Force -ErrorAction SilentlyContinue
	foreach ($candidate in $moduleCandidates) {
		if (Test-Path -LiteralPath $candidate.Path) {
			Remove-Item -LiteralPath $candidate.Path -Recurse -Force -ErrorAction Stop
		}
	}
	if (Test-Path -LiteralPath $targetPath) {
		Remove-Item -LiteralPath $targetPath -Recurse -Force -ErrorAction Stop
	}
	New-Item -ItemType Directory -Path $targetPath -Force -ErrorAction Stop | Out-Null

	try {
		$packageFiles = Get-ChildItem -LiteralPath $packageRoot -File -Recurse -ErrorAction Stop
		foreach ($packageFile in $packageFiles) {
			$relativePath = $packageFile.FullName.Substring($packageRoot.Length).TrimStart('\', '/')
			$destinationPath = Join-Path $targetPath $relativePath
			$destinationDirectory = Split-Path -Path $destinationPath -Parent
			New-Item -ItemType Directory -Path $destinationDirectory -Force -ErrorAction Stop | Out-Null
			Copy-Item -LiteralPath $packageFile.FullName -Destination $destinationPath -Force -ErrorAction Stop
		}
	}
	catch {
		Remove-Item -LiteralPath $targetPath -Recurse -Force -ErrorAction SilentlyContinue
		foreach ($backup in $backups) {
			New-Item -ItemType Directory -Path (Split-Path -Path $backup.OriginalPath -Parent) -Force -ErrorAction SilentlyContinue | Out-Null
			Copy-Item -Path (Join-Path $backup.BackupPath '*') -Destination $backup.OriginalPath -Recurse -Force -ErrorAction Stop
		}
		throw
	}

	Write-Output "StratoHiDriveUtils $releaseVersion was installed at '$targetPath'. Start a new Windows PowerShell session or import the module again."
}
catch {
	Write-Error $_.Exception.Message
	throw
}
finally {
	if ($temporaryRoot) {
		Remove-Item -LiteralPath $temporaryRoot -Recurse -Force -ErrorAction SilentlyContinue
	}
}
