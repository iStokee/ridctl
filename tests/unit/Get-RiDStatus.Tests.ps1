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