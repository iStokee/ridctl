Import-Module $PSScriptRoot/../../src -Force

Describe 'New-RiDVM VMware fallback without template' {
  It 'creates vanilla VMX when no template and vmrun present' {
    # Ensure provider resolves to vmware
    Mock Get-RiDProviderPreference { 'vmware' }
    # Tools: vmrun present, vmcli absent
    Mock Get-RiDVmTools { [pscustomobject]@{ VmCliPath=$null; VmrunPath='C:\\Program Files\\VMware\\VMware Workstation\\vmrun.exe' } }
    # Config: no template configured
    Mock Get-RiDConfig { @{ Templates=@{ DefaultVmx=''; DefaultSnapshot='' } } }
    # User prompts: choose Vanilla creation and skip ISO helper
    Mock Read-Host { 'Y' } -ParameterFilter { $Prompt -like 'Create a fresh VM*' }
    Mock Read-Host { 'n' } -ParameterFilter { $Prompt -like 'Launch ISO helper*' }
    Mock New-RiDVmVanilla { 'C:\\VMs\\Demo\\Demo.vmx' }
    { New-RiDVM -Name 'Demo' -DestinationPath 'C:\\VMs\\Demo' -CpuCount 2 -MemoryMB 2048 -DiskGB 20 -Method vmrun -WhatIf } | Should -Not -Throw
    Assert-MockCalled New-RiDVmVanilla -Times 1 -Exactly
  }
}

