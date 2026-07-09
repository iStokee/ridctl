BeforeAll {
    Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\ridctl.psd1') -Force
}

Describe 'Get-RiDProviderPreference (VMware-only)' {
    It 'returns vmware for default config' {
        InModuleScope ridctl {
            $cfg = Get-RiDDefaultConfig
            Get-RiDProviderPreference -Config $cfg | Should -Be 'vmware'
        }
    }

    It 'falls back to vmware with a warning when config requests hyperv' {
        InModuleScope ridctl {
            $cfg = Get-RiDDefaultConfig
            $cfg['Hypervisor']['Type'] = 'hyperv'
            $result = Get-RiDProviderPreference -Config $cfg -WarningVariable warn -WarningAction SilentlyContinue
            $result | Should -Be 'vmware'
            $warn | Should -Not -BeNullOrEmpty
        }
    }

    It 'returns vmware for auto' {
        InModuleScope ridctl {
            $cfg = Get-RiDDefaultConfig
            $cfg['Hypervisor']['Type'] = 'auto'
            Get-RiDProviderPreference -Config $cfg | Should -Be 'vmware'
        }
    }
}
