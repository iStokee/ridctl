Import-Module $PSScriptRoot/../../src -Force

Describe 'Resolve-RiDVmxFromName with Hyper-V' {
  It 'does not error when provider is hyperv and returns null' {
    Mock Find-RiDVmByName { @{ Name='HV'; Provider='hyperv'; VmxPath='' } }
    { $p = Resolve-RiDVmxFromName -Name 'HV' } | Should -Not -Throw
  }
}

