Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '..\..\src')

Describe 'Get-RiDStatus' {
    It 'returns an object with expected properties' {
        $status = Get-RiDStatus
        $status | Should -Not -BeNullOrEmpty
        $status | Should -HaveProperty 'IsVM'
        $status | Should -HaveProperty 'VTReady'
        $status | Should -HaveProperty 'VmwareToolsInstalled'
        $status | Should -HaveProperty 'SharedFolderOk'
        $status | Should -HaveProperty 'IsoAvailable'
        $status | Should -HaveProperty 'SyncNeeded'
    }
}
Import-Module $PSScriptRoot/../../src -Force

Describe 'Aggregate status fields' {
  It 'bubbles Hyper-V and WSL fields' {
    Mock Get-RiDHostGuestInfo { $false }
    Mock Get-RiDVirtSupport { [pscustomobject]@{
      VTEnabled=$true; HyperVPresent=$true; HyperVModule=$true;
      WindowsHypervisorPlatformPresent=$false; WslPresent=$true;
      HypervisorLaunchTypeActive=$false; MemoryIntegrityEnabled=$false
    } }
    Mock Get-RiDWorkstationInfo { [pscustomobject]@{ Installed=$true; Version='17.5.0' } }
    $s = Get-RiDStatus
    $s.HyperVPresent | Should -BeTrue
    $s.HyperVModule  | Should -BeTrue
    $s.WHPPresent    | Should -BeFalse
    $s | Get-Member -Name VmwareInstalled | Should -Not -BeNullOrEmpty
  }
}
