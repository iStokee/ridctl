BeforeAll {
    Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\ridctl.psd1') -Force
}

Describe 'Initialize-RiDGuest' {
    It 'extracts from a pre-seeded archive with -NoDownload' {
        InModuleScope ridctl {
            $dest = Join-Path $TestDrive 'RiD-Dest'
            New-Item -ItemType Directory -Path $dest | Out-Null

            # Create a dummy archive path (content not used because we mock extraction)
            $arc = Join-Path $TestDrive 'RiD.rar'
            Set-Content -Path $arc -Value 'dummy'

            # Mock 7-Zip discovery and process invocation
            Mock _Find-7Zip { 'C:\Program Files\7-Zip\7z.exe' }
            Mock _Invoke-Process { 0 }

            $rc = Initialize-RiDGuest -NoDownload -ArchivePath $arc -Destination $dest
            $rc | Should -Be 0

            Should -Invoke _Find-7Zip -Times 1 -Exactly
            Should -Invoke _Invoke-Process -Times 1 -ParameterFilter {
                $FilePath -match '7z.exe' -and $Arguments -match [regex]::Escape($arc) -and $Arguments -match [regex]::Escape($dest)
            }
        }
    }
}
