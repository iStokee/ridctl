BeforeAll {
    Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\ridctl.psd1') -Force
}

Describe 'Register-RiDVM ShouldProcess' {
    It 'honors -WhatIf and does not write' {
        InModuleScope ridctl {
            Mock Add-RiDVmRegistryEntry { throw 'Should not be called under -WhatIf' }
            { Register-RiDVM -Name 'X' -VmxPath 'C:\VMs\X\X.vmx' -WhatIf } | Should -Not -Throw
        }
    }
}

Describe 'Get-RiDVM LiteralPath' {
    It 'uses Test-Path -LiteralPath for special chars' {
        InModuleScope ridctl {
            Mock Get-RiDVmRegistry { @(@{ Name='Weird'; VmxPath='C:\VMs\[X]\X.vmx'; ShareName=''; HostPath=''; Notes='' }) }
            Mock Test-Path { $true } -ParameterFilter { $null -ne $LiteralPath }
            $v = Get-RiDVM | Select-Object -First 1
            $v.Exists | Should -BeTrue
        }
    }
}

Describe 'Resolve-RiDVmxFromName' {
    It 'does not throw for a legacy hyperv entry without VmxPath' {
        InModuleScope ridctl {
            Mock Find-RiDVmByName { @{ Name='HV'; Provider='hyperv'; VmxPath='' } }
            { Resolve-RiDVmxFromName -Name 'HV' } | Should -Not -Throw
        }
    }
}
