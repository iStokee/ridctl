Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '..\..\src')

Describe 'Get-RiDStatus IsoAvailable' {
    It 'returns IsoAvailable true when an ISO exists in configured dir' {
        $isoDir = Join-Path $TestDrive 'isos'
        New-Item -ItemType Directory -Path $isoDir | Out-Null
        # create a dummy iso file
        $isoPath = Join-Path $isoDir 'dummy.iso'
        Set-Content -Path $isoPath -Value 'not a real iso'

        # Point ridctl at a test-local config file
        $cfgPath = Join-Path $TestDrive 'config.json'
        $cfg = @{ Iso = @{ DefaultDownloadDir = $isoDir } }
        $cfg | ConvertTo-Json -Depth 5 | Out-File -LiteralPath $cfgPath -Encoding UTF8
        $env:RIDCTL_CONFIG = $cfgPath

        $status = Get-RiDStatus
        $status.IsoAvailable | Should -BeTrue
    }
}

