Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '..\..\src')

Describe 'Compare-RiDFiles' {
    It 'identifies only-in-left and only-in-right and newer files' {
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
        Start-Sleep -Milliseconds 10
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

