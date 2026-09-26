<#
.SYNOPSIS
Pester tests for Install-StratoHiDriveUtils.ps1.

.DESCRIPTION
Runs a copy of the installer that targets a TestDrive module folder instead of the user's Documents folder and checks migration, reuse, -WhatIf, the irm | iex path, and PSModulePath validation.
GitHub calls are replaced by mocks that serve a release ZIP built from the working tree.
Requires Windows PowerShell 5.1 and Pester 5.

.EXAMPLE
Invoke-Pester -Path .\Tests\Install-StratoHiDriveUtils.Tests.ps1 -Output Detailed

Runs the installer tests from the repository root.
#>

#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between setup and test blocks.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '', Justification = 'Reproduces the documented irm | iex installation of the installer.')]
param()

Set-StrictMode -Version Latest

BeforeAll {
	. (Join-Path $PSScriptRoot 'TestHelpers.ps1')
	$script:releaseZip = Join-Path $TestDrive 'release.zip'
	New-TestReleaseZip -Path $script:releaseZip -ManifestVersion $script:releaseVersion.ToString()
}

Describe 'Install-StratoHiDriveUtils.ps1' {
	BeforeAll {
		$script:originalModulePath = $env:PSModulePath
	}

	BeforeEach {
		$moduleBase = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
		$moduleRoot = Join-Path $moduleBase $script:moduleName
		$targetPath = Join-Path $moduleRoot $script:releaseVersion.ToString()
		New-Item -ItemType Directory -Path $moduleBase -Force | Out-Null
		$env:PSModulePath = $moduleBase

		# The installer always targets the user's Documents module folder, so the test runs a copy that targets the sandbox instead.
		$installerSource = Get-Content -LiteralPath $script:installerPath -Raw
		$userModuleBaseExpression = "[System.IO.Path]::GetFullPath((Join-Path `$userDocuments 'WindowsPowerShell\Modules')).TrimEnd('\')"
		$installerSource.Contains($userModuleBaseExpression) | Should -BeTrue -Because 'the test redirects this expression to the sandbox'
		$testInstaller = Join-Path $TestDrive "Install-$([guid]::NewGuid().ToString('N')).ps1"
		Set-Content -LiteralPath $testInstaller -Value $installerSource.Replace($userModuleBaseExpression, "'$moduleBase'") -Encoding UTF8

		# The installer runs in its own script scope, so the mocks use local variables instead of script-scoped ones.
		$installerReleaseResponse = Get-TestRelease
		$installerReleaseZip = $script:releaseZip
		Mock -CommandName Invoke-RestMethod -MockWith { $installerReleaseResponse }
		Mock -CommandName Invoke-WebRequest -MockWith { Copy-Item -LiteralPath $installerReleaseZip -Destination $OutFile }
	}

	AfterEach {
		$env:PSModulePath = $script:originalModulePath
	}

	It 'replaces flat, Git, older, and legacy installations with the release version folder' {
		New-TestInstallation -Path $moduleRoot -Version '2.1.0'
		New-Item -ItemType Directory -Path (Join-Path $moduleRoot '.git') | Out-Null
		New-TestInstallation -Path (Join-Path $moduleRoot '2.0.0') -Version '2.0.0'
		$legacyRoot = Join-Path $moduleBase 'StratoHiDriveUtils'
		New-Item -ItemType Directory -Path $legacyRoot | Out-Null
		Set-Content -LiteralPath (Join-Path $legacyRoot 'StratoHiDriveUtils.psd1') -Value "@{ ModuleVersion = '1.1.6' }"

		& $testInstaller -Force | Should -Match 'was installed at'

		@(Get-ChildItem -LiteralPath $moduleBase -Force | Select-Object -ExpandProperty Name) | Should -Be @($script:moduleName)
		@(Get-ChildItem -LiteralPath $moduleRoot -Force | Select-Object -ExpandProperty Name) | Should -Be @($script:releaseVersion.ToString())
		@(Get-ChildItem -LiteralPath $targetPath -File | Select-Object -ExpandProperty Name | Sort-Object) | Should -Be @($script:manifestData.FileList | Sort-Object)
	}

	It 'makes no changes when the release version is already installed' {
		New-TestInstallation -Path $targetPath -Version $script:releaseVersion.ToString()

		& $testInstaller -Force | Should -Match 'already installed'

		Should -Invoke -CommandName Invoke-WebRequest -Times 0 -Exactly
	}

	It 'makes no changes with -WhatIf' {
		New-TestInstallation -Path (Join-Path $moduleRoot '2.0.0') -Version '2.0.0'

		& $testInstaller -WhatIf | Should -Match 'No changes were made'

		$targetPath | Should -Not -Exist
		Join-Path $moduleRoot '2.0.0' | Should -Exist
	}

	It 'installs without a prompt when run through Invoke-Expression like the README command' {
		New-TestInstallation -Path $moduleRoot -Version '2.1.0'

		Get-Content -LiteralPath $testInstaller -Raw | Invoke-Expression | Should -Match 'was installed at'

		Join-Path $targetPath "$script:moduleName.psd1" | Should -Exist
		Join-Path $moduleRoot "$script:moduleName.psd1" | Should -Not -Exist
	}

	It 'throws when the target module folder is not in PSModulePath' {
		$env:PSModulePath = Join-Path $TestDrive 'Elsewhere'

		{ & $testInstaller -Force } | Should -Throw -ExpectedMessage '*is not part of the current PSModulePath*'
	}
}
