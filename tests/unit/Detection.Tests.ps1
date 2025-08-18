Import-Module $PSScriptRoot/../../src -Force

Describe 'WSL detection' {
  It 'detects store-based WSL via --version' {
    Mock Get-WindowsOptionalFeature { @{ State = 'Disabled' } } -ParameterFilter { $FeatureName -eq 'Microsoft-Windows-Subsystem-Linux' }
    Mock Get-Command { [pscustomobject]@{ Source = 'wsl.exe' } } -ParameterFilter { $Name -match '^wsl' }
    Mock Out-String { 'WSL version 2' }
    Mock Test-Path { $false } -ParameterFilter { $Path -match 'Lxss' }
    $r = Get-RiDVirtSupport
    $r.WslPresent | Should -BeTrue
  }

  It 'detects WSL via optional feature' {
    Mock Get-WindowsOptionalFeature { @{ State = 'Enabled' } } -ParameterFilter { $FeatureName -eq 'Microsoft-Windows-Subsystem-Linux' }
    Mock Get-Command { $null } -ParameterFilter { $Name -match '^wsl' }
    Mock Test-Path { $false } -ParameterFilter { $Path -match 'Lxss' }
    $r = Get-RiDVirtSupport
    $r.WslPresent | Should -BeTrue
  }
  It 'detects WSL via registry only' {
    Mock Get-WindowsOptionalFeature { @{ State = 'Disabled' } } -ParameterFilter { $FeatureName -eq 'Microsoft-Windows-Subsystem-Linux' }
    Mock Get-Command { $null } -ParameterFilter { $Name -match '^wsl' }
    Mock Test-Path { $true } -ParameterFilter { $Path -match 'Lxss' }
    $r = Get-RiDVirtSupport
    $r.WslPresent | Should -BeTrue
  }
}

Describe 'Hyper-V and WHP detection' {
  It 'reports Hyper-V present and WHP' {
    Mock Get-WindowsOptionalFeature {
      switch ($FeatureName) {
        'Microsoft-Hyper-V-All' { return @{ State = 'Enabled' } }
        'HypervisorPlatform'    { return @{ State = 'Enabled' } }
        default                 { return @{ State = 'Disabled' } }
      }
    }
    Mock Get-Module { 1 } -ParameterFilter { $Name -eq 'Hyper-V' -and $ListAvailable }
    $r = Get-RiDVirtSupport
    $r.HyperVPresent | Should -BeTrue
    ($r.WindowsHypervisorPlatformPresent -or $r.WindowsHypervisorPlatform) | Should -BeTrue
    $r.HyperVModule | Should -BeTrue
  }
}
