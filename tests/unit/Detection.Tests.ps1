BeforeAll {
    Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\ridctl.psd1') -Force
}

Describe 'WSL detection' {
    It 'detects WSL via optional feature' {
        InModuleScope ridctl {
            Mock Get-WindowsOptionalFeature { @{ State = 'Enabled' } } -ParameterFilter { $FeatureName -eq 'Microsoft-Windows-Subsystem-Linux' }
            Mock Get-Command { $null } -ParameterFilter { $Name -match '^wsl' }
            Mock Test-Path { $false } -ParameterFilter { $Path -match 'Lxss' }
            $r = Get-RiDVirtSupport
            $r.WslPresent | Should -BeTrue
        }
    }

    It 'detects WSL via registry only' {
        InModuleScope ridctl {
            Mock Get-WindowsOptionalFeature { @{ State = 'Disabled' } } -ParameterFilter { $FeatureName -eq 'Microsoft-Windows-Subsystem-Linux' }
            Mock Get-Command { $null } -ParameterFilter { $Name -match '^wsl' }
            Mock Test-Path { $true } -ParameterFilter { $Path -match 'Lxss' }
            $r = Get-RiDVirtSupport
            $r.WslPresent | Should -BeTrue
        }
    }
}

Describe 'Hyper-V and WHP detection' {
    It 'reports Hyper-V present and WHP' {
        InModuleScope ridctl {
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
}
