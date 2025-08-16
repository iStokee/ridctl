Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '..\..\src')

Describe 'Invoke-RiDSync' {
    It 'plans bidirectional copies in dry-run' {
        $local = Join-Path $TestDrive 'local'
        $share = Join-Path $TestDrive 'share'
        New-Item -ItemType Directory -Path $local,$share | Out-Null

        # local only and newer
        Set-Content -Path (Join-Path $local 'x.txt') -Value 'L'
        # share only
        Set-Content -Path (Join-Path $share 'y.txt') -Value 'S'
        # both with local newer
        Set-Content -Path (Join-Path $share 'z.txt') -Value 'old'
        Start-Sleep -Milliseconds 10
        Set-Content -Path (Join-Path $local 'z.txt') -Value 'new'

        $sum = Invoke-RiDSync -LocalPath $local -SharePath $share -Mode Bidirectional -DryRun
        $sum.Total | Should -BeGreaterThan 0
        ($sum.Plan | Where-Object { $_.Action -eq 'Copy' -and $_.Direction -eq 'LocalToShare' -and $_.RelativePath -eq 'x.txt' }).Count | Should -Be 1
        ($sum.Plan | Where-Object { $_.Action -eq 'Copy' -and $_.Direction -eq 'ShareToLocal' -and $_.RelativePath -eq 'y.txt' }).Count | Should -Be 1
        ($sum.Plan | Where-Object { $_.Action -eq 'Copy' -and $_.Direction -eq 'LocalToShare' -and $_.RelativePath -eq 'z.txt' }).Count | Should -Be 1
    }

    It 'applies ToShare copies when confirmed' {
        $local = Join-Path $TestDrive 'local2'
        $share = Join-Path $TestDrive 'share2'
        New-Item -ItemType Directory -Path $local,$share | Out-Null

        Set-Content -Path (Join-Path $local 'onlyLocal.txt') -Value 'L2'

        $sum = Invoke-RiDSync -LocalPath $local -SharePath $share -Mode ToShare -Apply
        Test-Path (Join-Path $share 'onlyLocal.txt') | Should -BeTrue
        $sum.Applied | Should -BeGreaterThan 0
    }
}

