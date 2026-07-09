BeforeAll {
    Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\ridctl.psd1') -Force
}

Describe 'Optimize-RiDGuest' {
    It 'refuses to run on a host without -Force' {
        InModuleScope ridctl {
            Mock Get-RiDHostGuestInfo { $false }
            Mock Invoke-RiDGuestDebloat { throw 'Should not run on host' }
            $null = Optimize-RiDGuest -WhatIf -WarningVariable warn -WarningAction SilentlyContinue
            $warn | Should -Not -BeNullOrEmpty
        }
    }

    It 'plans but does not apply under -WhatIf' {
        InModuleScope ridctl {
            Mock Get-RiDHostGuestInfo { $true }
            Mock Invoke-RiDGuestDebloat { [pscustomobject]@{ Removed=0; Planned=5; Failed=0; Applied=$Apply } }
            $r = Optimize-RiDGuest -WhatIf
            $r.Applied | Should -BeFalse
            Should -Invoke Invoke-RiDGuestDebloat -Times 1 -ParameterFilter { -not $Apply }
        }
    }
}

Describe 'Get-RiDDebloatRegistryTweaks' {
    It 'returns well-formed tweak entries and does not write in dry-run' {
        InModuleScope ridctl {
            $tweaks = Get-RiDDebloatRegistryTweaks
            $tweaks.Count | Should -BeGreaterThan 5
            foreach ($t in $tweaks) {
                $t.Path | Should -Match '^HK(LM|CU):'
                $t.Name | Should -Not -BeNullOrEmpty
                $t.Description | Should -Not -BeNullOrEmpty
            }
            $r = Set-RiDDebloatRegistryTweaks   # no -Apply: plan only
            $r.Applied | Should -Be 0
            $r.Planned | Should -Be $tweaks.Count
        }
    }
}

Describe 'Get-RiDDebloatAppxTargets' {
    It 'never targets infrastructure packages' {
        InModuleScope ridctl {
            $targets = Get-RiDDebloatAppxTargets
            foreach ($keep in @('Microsoft.WindowsStore','Microsoft.DesktopAppInstaller','Microsoft.VCLibs.140.00','Microsoft.NET.Native.Framework.2.2','Microsoft.WindowsTerminal','Microsoft.Xbox.TCUI','Microsoft.XboxIdentityProvider','Microsoft.XboxSpeechToTextOverlay')) {
                foreach ($t in $targets) {
                    $keep -like $t | Should -BeFalse -Because "pattern '$t' must not match '$keep'"
                }
            }
        }
    }
}
