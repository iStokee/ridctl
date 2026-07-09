BeforeAll {
    Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\ridctl.psd1') -Force
}

Describe 'Get-RiDStatus' {
    It 'returns an object with expected properties' {
        $status = Get-RiDStatus
        $status | Should -Not -BeNullOrEmpty
        foreach ($p in @('IsVM','VTReady','VmwareToolsInstalled','SharedFolderOk','IsoAvailable','SyncNeeded','Role','VmwareInstalled')) {
            $status.PSObject.Properties.Name | Should -Contain $p
        }
    }
}

Describe 'Aggregate status fields' {
    It 'bubbles virtualization and VMware fields' {
        InModuleScope ridctl {
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
            $s.VmwareInstalled | Should -BeTrue
        }
    }
}
