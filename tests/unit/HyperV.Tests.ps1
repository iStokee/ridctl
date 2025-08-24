Import-Module $PSScriptRoot/../../src -Force

Describe 'Provider resolution' {
  It 'prefers vmware when auto and vmware present' {
    Mock Get-RiDVirtSupport { [pscustomobject]@{ VmwarePresent=$true; HyperVPresent=$false } }
    $cfg = Get-RiDDefaultConfig
    $cfg['Hypervisor']['Type'] = 'auto'
    (Get-RiDProviderPreference -Config $cfg) | Should -Be 'vmware'
  }
  It 'falls back to hyperv when vmware not present' {
    Mock Get-RiDVirtSupport { [pscustomobject]@{ VmwarePresent=$false; HyperVPresent=$true } }
    $cfg = Get-RiDDefaultConfig
    $cfg['Hypervisor']['Type'] = 'auto'
    (Get-RiDProviderPreference -Config $cfg) | Should -Be 'hyperv'
  }
  It 'respects forced hyperv' {
    $cfg = Get-RiDDefaultConfig
    $cfg['Hypervisor']['Type'] = 'hyperv'
    (Get-RiDProviderPreference -Config $cfg) | Should -Be 'hyperv'
  }
}

Describe 'Routing to Hyper-V' {
  It 'Start-RiDVM routes to Start-RiDHvVM when provider=hyperv' {
    Mock Get-RiDProviderPreference { 'hyperv' }
    Mock Start-RiDHvVM { }
    { Start-RiDVM -Name 'Demo' -WhatIf } | Should -Not -Throw
    Assert-MockCalled Start-RiDHvVM -Times 1 -Exactly -ParameterFilter { $Name -eq 'Demo' }
  }
  It 'New-RiDVM routes to New-RiDHvVM when provider=hyperv' {
    Mock Get-RiDProviderPreference { 'hyperv' }
    Mock New-RiDHvVM { }
    { New-RiDVM -Name 'Demo' -DestinationPath 'C:\\VMs\\Demo' -WhatIf } | Should -Not -Throw
    Assert-MockCalled New-RiDHvVM -Times 1 -ParameterFilter { $Path -eq 'C:\\VMs\\Demo' -and $VhdPath -eq 'C:\\VMs\\Demo\\Demo.vhdx' }
  }
  It 'Stop-RiDVM routes to Stop-RiDHvVM when provider=hyperv' {
    Mock Get-RiDProviderPreference { 'hyperv' }
    Mock Stop-RiDHvVM { }
    { Stop-RiDVM -Name 'Demo' -WhatIf } | Should -Not -Throw
    Assert-MockCalled Stop-RiDHvVM -Times 1 -Exactly -ParameterFilter { $Name -eq 'Demo' -and -not $Hard }
  }
}

Describe 'Register-RiDVM supports Hyper-V without VMX' {
  It 'registers with Provider=hyperv and empty VmxPath' {
    Mock Get-RiDProviderPreference { 'hyperv' }
    Mock Add-RiDVmRegistryEntry { param($Entry) return @(@{ Name=$Entry.Name; VmxPath=$Entry.VmxPath; Provider=$Entry.Provider }) }
    $r = Register-RiDVM -Name 'HV' -Provider hyperv -WhatIf:$false
    $r | Should -Not -BeNullOrEmpty
  }
}

Describe 'Register-RiDVM ShouldProcess' {
  It 'honors -WhatIf and does not write' {
    Mock Add-RiDVmRegistryEntry { throw 'Should not be called under -WhatIf' }
    { Register-RiDVM -Name 'X' -VmxPath 'C:\\VMs\\X\\X.vmx' -WhatIf } | Should -Not -Throw
  }
}

Describe 'Get-RiDVM LiteralPath' {
  It 'uses Test-Path -LiteralPath for special chars' {
    Mock Get-RiDVmRegistry { @(@{ Name='Weird'; VmxPath='C:\\VMs\\[X],v\nX.vmx'; ShareName=''; HostPath=''; Notes='' }) }
    Mock Test-Path { $true } -ParameterFilter { $LiteralPath -ne $null }
    $v = Get-RiDVM | Select-Object -First 1
    $v.Exists | Should -BeTrue
  }
}

Describe 'Stop-RiDHvVM switch behaviour' {
  It 'uses Shutdown for soft stops' {
    Mock Stop-VM { }
    { Stop-RiDHvVM -Name 'Demo' -WhatIf } | Should -Not -Throw
    Assert-MockCalled Stop-VM -Times 1 -ParameterFilter { $Name -eq 'Demo' -and $Shutdown }
  }
  It 'uses TurnOff for hard stops' {
    Mock Stop-VM { }
    { Stop-RiDHvVM -Name 'Demo' -Hard -WhatIf } | Should -Not -Throw
    Assert-MockCalled Stop-VM -Times 1 -ParameterFilter { $Name -eq 'Demo' -and $TurnOff }
  }
}
