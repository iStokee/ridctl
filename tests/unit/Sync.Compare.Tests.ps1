BeforeAll {
    Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\ridctl.psd1') -Force
}

Describe 'Compare-RiDFiles' {
    It 'identifies only-in-left and only-in-right and newer files' {
        InModuleScope ridctl {
            $left  = Join-Path $TestDrive 'left'
            $right = Join-Path $TestDrive 'right'
            New-Item -ItemType Directory -Path $left,$right | Out-Null

            # only in left
            Set-Content -Path (Join-Path $left 'a.txt') -Value 'A'
            # only in right
            Set-Content -Path (Join-Path $right 'b.txt') -Value 'B'
            # both but left newer
            $bothL = Join-Path $left 'c.txt'
            $bothR = Join-Path $right 'c.txt'
            Set-Content -Path $bothR -Value 'old'
            Start-Sleep -Milliseconds 50
            Set-Content -Path $bothL -Value 'new'

            $res = Compare-RiDFiles -SourcePath $left -DestPath $right
            $map = @{}
            foreach ($e in $res) { $map[$e.RelativePath] = $e }

            $map['a.txt'].SourceExists | Should -BeTrue
            $map['a.txt'].DestExists   | Should -BeFalse

            $map['b.txt'].SourceExists | Should -BeFalse
            $map['b.txt'].DestExists   | Should -BeTrue

            $map['c.txt'].DiffReason   | Should -Be 'SourceNewer'
        }
    }

    It 'honors exclude patterns' {
        InModuleScope ridctl {
            $left  = Join-Path $TestDrive 'exl'
            $right = Join-Path $TestDrive 'exr'
            New-Item -ItemType Directory -Path $left,$right | Out-Null
            Set-Content -Path (Join-Path $left 'keep.txt') -Value 'K'
            Set-Content -Path (Join-Path $left 'skip.log') -Value 'S'

            $res = Compare-RiDFiles -SourcePath $left -DestPath $right -Excludes @('*.log')
            ($res | Where-Object { $_.RelativePath -eq 'skip.log' }) | Should -BeNullOrEmpty
            ($res | Where-Object { $_.RelativePath -eq 'keep.txt' }) | Should -Not -BeNullOrEmpty
        }
    }
}
