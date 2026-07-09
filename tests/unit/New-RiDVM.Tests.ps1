BeforeAll {
    Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\ridctl.psd1') -Force
}

Describe 'New-RiDVM method routing' {
    It 'falls back to vanilla creation when no template configured' {
        InModuleScope ridctl {
            Mock Get-RiDConfig { @{ Templates=@{ DefaultVmx=''; DefaultSnapshot='' } } }
            Mock New-RiDVmVanilla { 'C:\VMs\Demo\Demo.vmx' }
            Mock Register-RiDVM { }
            { New-RiDVM -Name 'Demo' -DestinationPath 'C:\VMs\Demo' -CpuCount 2 -MemoryMB 2048 -DiskGB 20 -IsoPath 'C:\ISO\win11.iso' -Confirm:$false } | Should -Not -Throw
            Should -Invoke New-RiDVmVanilla -Times 1 -Exactly
            Should -Invoke Register-RiDVM -Times 1 -Exactly
        }
    }

    It 'does not create anything under -WhatIf' {
        InModuleScope ridctl {
            Mock Get-RiDConfig { @{ Templates=@{ DefaultVmx=''; DefaultSnapshot='' } } }
            Mock New-RiDVmVanilla { throw 'Should not be called under -WhatIf' }
            Mock Register-RiDVM { throw 'Should not be called under -WhatIf' }
            { New-RiDVM -Name 'Demo' -DestinationPath 'C:\VMs\Demo' -IsoPath 'C:\ISO\win11.iso' -WhatIf } | Should -Not -Throw
        }
    }

    It 'clones via vmrun when a template is configured' {
        InModuleScope ridctl {
            $tpl = Join-Path $TestDrive 'tpl.vmx'
            Set-Content -Path $tpl -Value 'dummy'
            Mock Get-RiDVmTools { [pscustomobject]@{ VmrunPath='C:\Program Files\VMware\VMware Workstation\vmrun.exe' } }
            Mock Clone-RiDVmrunTemplate { }
            Mock Set-RiDVmxSettings { }
            Mock Register-RiDVM { }
            { New-RiDVM -Name 'Demo' -DestinationPath 'C:\VMs\Demo' -TemplateVmx $tpl -TemplateSnapshot 'Clean' -Confirm:$false } | Should -Not -Throw
            Should -Invoke Clone-RiDVmrunTemplate -Times 1 -Exactly
        }
    }

    It 'warns and stops when clone requested without a template' {
        InModuleScope ridctl {
            Mock Get-RiDConfig { @{ Templates=@{ DefaultVmx=''; DefaultSnapshot='' } } }
            Mock Get-RiDVmTools { [pscustomobject]@{ VmrunPath='C:\vmrun.exe' } }
            Mock Clone-RiDVmrunTemplate { throw 'Should not be called without template' }
            $null = New-RiDVM -Name 'Demo' -DestinationPath 'C:\VMs\Demo' -Method clone -WhatIf -WarningVariable warn -WarningAction SilentlyContinue
            $warn | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'New-RiDVmVanilla VMX content' {
    It 'writes a Windows 11-ready VMX (EFI, secure boot, vTPM)' {
        InModuleScope ridctl {
            $dest = Join-Path $TestDrive 'vmx'
            Mock Get-RiDWorkstationInfo { [pscustomobject]@{ Installed=$true; InstallPath=$TestDrive; Version='17.5' } }
            # Pretend vdiskmanager exists and the disk gets created
            $vdm = Join-Path $TestDrive 'vmware-vdiskmanager.exe'
            Set-Content -Path $vdm -Value 'stub'
            New-Item -ItemType Directory -Path $dest -Force | Out-Null
            Set-Content -Path (Join-Path $dest 'Demo.vmdk') -Value 'stub-disk'

            $vmx = New-RiDVmVanilla -Name 'Demo' -DestinationPath $dest -CpuCount 2 -MemoryMB 4096 -DiskGB 60 -IsoPath 'C:\ISO\win11.iso' -Confirm:$false
            $vmx | Should -Not -BeNullOrEmpty
            $content = Get-Content -LiteralPath $vmx -Raw
            $content | Should -Match 'firmware = "efi"'
            $content | Should -Match 'efi\.secureBoot\.enabled = "TRUE"'
            $content | Should -Match 'managedvm\.autoAddVTPM = "software"'
            $content | Should -Match 'guestOS = "windows11-64"'
            $content | Should -Match 'win11\.iso'
        }
    }
}
