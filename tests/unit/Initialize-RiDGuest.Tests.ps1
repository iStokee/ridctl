Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '..\..\src')

Describe 'Initialize-RiDGuest' {
    It 'extracts from a pre-seeded archive with -NoDownload' {
        $dest = Join-Path $TestDrive 'RiD-Dest'
        New-Item -ItemType Directory -Path $dest | Out-Null

        # Create a dummy archive path (content not used because we mock extraction)
        $arc = Join-Path $TestDrive 'RiD.rar'
        Set-Content -Path $arc -Value 'dummy'

        # Mock 7-Zip discovery and process invocation
        Mock -CommandName _Find-7Zip -MockWith { 'C:\\Program Files\\7-Zip\\7z.exe' }
        Mock -CommandName _Invoke-Process -MockWith { 0 }

        $rc = Initialize-RiDGuest -NoDownload -ArchivePath $arc -Destination $dest -Verbose
        $rc | Should -Be 0

        Assert-MockCalled -CommandName _Find-7Zip -Times 1 -Exactly
        Assert-MockCalled -CommandName _Invoke-Process -Times 1 -ParameterFilter {
            $FilePath -match '7z.exe' -and $Arguments -match [regex]::Escape($arc) -and $Arguments -match [regex]::Escape($dest)
        }
    }
}

