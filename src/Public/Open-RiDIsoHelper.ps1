function Open-RiDIsoHelper {
    <#
    .SYNOPSIS
      Interactive ISO helper submenu for acquiring Windows ISOs.

    .DESCRIPTION
      Presents a submenu with guided and automated paths to obtain a
      Windows ISO using the Fido integration. Options include a quick
      headless download using configured defaults, an advanced flow to
      choose Version/Release/Edition/Language/Arch, opening the Fido UI
      interactively, installing/updating the Fido script, listing
      available Fido options, and picking an existing ISO file.

      Returns the selected/downloaded ISO file path or $null if the user
      cancels or backs out.

    .EXAMPLE
      PS> Open-RiDIsoHelper
    #>
    [CmdletBinding()] param()

    function _S([object]$v) {
        if ($null -eq $v) { return '' }
        if ($v -is [System.Collections.IDictionary] -or ($v -is [System.Collections.IEnumerable] -and -not ($v -is [string]))) {
            return (ConvertTo-Json -InputObject $v -Depth 5 -Compress)
        }
        return [string]$v
    }

    try {
        $cfg = Initialize-RiDConfig
        if (-not $cfg['Iso']) { $cfg['Iso'] = @{} }
        $defaultDir = if (_S $cfg['Iso']['DefaultDownloadDir']) { _S $cfg['Iso']['DefaultDownloadDir'] } else { 'C:\\ISO' }
        # Fallback if still empty or invalid
        if (-not $defaultDir) { $defaultDir = 'C:\\ISO' }

        while ($true) {
            Clear-Host
            Write-RiDHeader -Title 'RiD Control > ISO Helper'
            Write-Host 'Choose an action:' -ForegroundColor Green
            Write-Host ('Default download dir: ' + $defaultDir) -ForegroundColor DarkGray
            Write-Host ''
            Write-Host '  1) Quick: Auto-download Win11 (headless)'
            Write-Host '  2) Advanced: Choose options + download'
            Write-Host '  3) Get URL only (no download)'
            Write-Host '  4) Open Fido UI (interactive)'
            Write-Host '  5) Install/Update Fido script'
            Write-Host '  6) List available options (Fido)'
            Write-Host '  7) Pick existing ISO file'
            Write-Host '  X) Back'
            $sel = Read-Host 'Select an option [1]'
            if (-not $sel) { $sel = '1' }

            switch ($sel.ToUpper()) {
                '1' {
                    try {
                        # Quick headless path uses our wrapper which will fall back to UI if needed
                        $langPref = 'en-US'
                        $iso = Invoke-RiDFidoDownload -Version 'win11' -Language $langPref -Destination $defaultDir -TryNonInteractive
                        if ($iso) { return $iso }
                        else { Write-Host 'No ISO selected or download failed.' -ForegroundColor Yellow; Pause-RiD }
                    } catch { Write-Error $_; Pause-RiD }
                }

                '2' {
                    try {
                        # Advanced headless selection with option prompts
                        $curVer = Read-Host 'Windows Version [11/10] (default 11)'
                        if (-not $curVer) { $curVer = '11' }
                        if ($curVer -notin @('11','10')) { Write-Host 'Invalid version.' -ForegroundColor Yellow; break }

                        $relDef = if (_S $cfg['Iso']['Release']) { _S $cfg['Iso']['Release'] } else { 'Latest' }
                        $edDef  = if (_S $cfg['Iso']['Edition']) { _S $cfg['Iso']['Edition'] } else { 'Home/Pro' }
                        $arDef  = if (_S $cfg['Iso']['Arch'])    { _S $cfg['Iso']['Arch'] }    else { 'x64' }
                        $langDef = 'English International'

                        $rel = Read-Host ("Release (e.g., Latest/23H2) [{0}]" -f $relDef); if (-not $rel) { $rel = $relDef }
                        $ed  = Read-Host ("Edition (e.g., Home/Pro) [{0}]" -f $edDef);       if (-not $ed)  { $ed  = $edDef }
                        $ar  = Read-Host ("Arch [x64/x86/arm64] [{0}]" -f $arDef);            if (-not $ar)  { $ar  = $arDef }
                        $ln  = Read-Host ("Language [{0}]" -f $langDef);                       if (-not $ln)  { $ln  = $langDef }
                        $dir = Read-Host ("Download directory [{0}]" -f $defaultDir);          if (-not $dir) { $dir = $defaultDir }
                        if ([string]::IsNullOrWhiteSpace($dir)) { try { $dir = (Resolve-Path '.').Path } catch { $dir = $pwd.Path } }
                        try { if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null } } catch {}

                        $mode = Read-Host 'Mode: (D)ownload file or (U)RL only? [D]'
                        $ts = (Get-Date).ToString('yyyyMMdd_HHmmss')
                        $outName = "Win{0}_{1}_{2}_{3}.iso" -f $curVer,($ln -replace '\\s+',''),$ar,$ts
                        if ([string]::IsNullOrWhiteSpace($dir)) { throw 'Download directory is empty; cannot build output path.' }
                        $outPath = Join-Path -Path $dir -ChildPath $outName

                        if ($mode -match '^[Uu]') {
                            $url = Get-RiDWindowsIso -Version $curVer -Release $rel -Edition $ed -Language $ln -Arch $ar -GetUrl
                            if ($url) {
                                Write-Host ("URL: {0}" -f $url) -ForegroundColor Cyan
                                if (Read-RiDYesNo -Prompt 'Copy URL to clipboard?' -Default No) { try { Set-Clipboard -Value $url } catch { Write-Warning 'Clipboard unavailable.' } }
                                Pause-RiD
                            } else {
                                Write-Host 'Failed to obtain URL.' -ForegroundColor Yellow; Pause-RiD
                            }
                        } else {
                            $file = Get-RiDWindowsIso -Version $curVer -Release $rel -Edition $ed -Language $ln -Arch $ar -OutFile $outPath
                            if ($file -and (Test-Path -LiteralPath $file)) { return $file }
                            else { Write-Host 'Download failed.' -ForegroundColor Yellow; Pause-RiD }
                        }
                    } catch { Write-Error $_; Pause-RiD }
                }

                '3' {
                    try {
                        $ver = Read-Host 'Windows Version [11/10] (default 11)'; if (-not $ver) { $ver = '11' }
                        $rel = Read-Host 'Release (e.g., Latest/23H2) [Latest]'; if (-not $rel) { $rel = 'Latest' }
                        $ed  = Read-Host 'Edition (e.g., Home/Pro) [Home/Pro]';   if (-not $ed)  { $ed  = 'Home/Pro' }
                        $ln  = Read-Host 'Language [English International]';      if (-not $ln)  { $ln  = 'English International' }
                        $ar  = Read-Host 'Arch [x64/x86/arm64] [x64]';            if (-not $ar)  { $ar  = 'x64' }
                        $url = Get-RiDWindowsIso -Version $ver -Release $rel -Edition $ed -Language $ln -Arch $ar -GetUrl
                        if ($url) { Write-Host ("URL: {0}" -f $url) -ForegroundColor Cyan }
                        else { Write-Host 'Failed to obtain URL.' -ForegroundColor Yellow }
                    } catch { Write-Error $_ }
                    Pause-RiD
                }

                '4' {
                    try {
                        $verPick = Read-Host 'Version: win11 or win10 [win11]'; if (-not $verPick) { $verPick = 'win11' }
                        $lang    = Read-Host 'Language (locale or name) [en-US]'; if (-not $lang) { $lang = 'en-US' }
                        $iso = Invoke-RiDFidoDownload -Version $verPick -Language $lang -Destination $defaultDir
                        if ($iso) { return $iso }
                        else { Write-Host 'No ISO selected.' -ForegroundColor Yellow; Pause-RiD }
                    } catch { Write-Error $_; Pause-RiD }
                }

                '5' {
                    try {
                        $pin = Read-Host 'Pin Fido to specific commit? (leave blank for latest)'
                        if ($pin) { $null = Install-RiDFido -PinToCommit $pin -PersistConfig -Apply }
                        else { $null = Install-RiDFido -PersistConfig -Apply }
                        Write-Host 'Fido installation attempted. Configure path under Options if needed.' -ForegroundColor Cyan
                    } catch { Write-Error $_ }
                    Pause-RiD
                }

                '6' {
                    try {
                        $v = Read-Host 'List (Win/Rel/Ed/Lang) [Win]'; if (-not $v) { $v = 'Win' }
                        $ver = Read-Host 'Version for Rel/Ed/Lang [11]'; if (-not $ver) { $ver = '11' }
                        $rel = Read-Host 'Release for Ed/Lang [Latest]'; if (-not $rel) { $rel = 'Latest' }
                        $ed  = Read-Host 'Edition for Lang [Home/Pro]';  if (-not $ed)  { $ed  = 'Home/Pro' }
                        $list = Get-RiDFidoList -List $v -Version $ver -Release $rel -Edition $ed
                        if ($list -and $list.Count -gt 0) { $list | ForEach-Object { Write-Host ('  ' + $_) } }
                        else { Write-Host 'No data.' -ForegroundColor Yellow }
                    } catch { Write-Error $_ }
                    Pause-RiD
                }

                '7' {
                    try {
                        $init = if (Test-Path -LiteralPath $defaultDir) { $defaultDir } else { $env:USERPROFILE }
                        $iso = Show-RiDOpenFileDialog -InitialDirectory $init -Filter 'ISO files (*.iso)|*.iso|All files (*.*)|*.*' -Title 'Select Windows ISO'
                        if ($iso) { return $iso }
                        else { Write-Host 'No file selected.' -ForegroundColor Yellow; Pause-RiD }
                    } catch { Write-Error $_; Pause-RiD }
                }

                'X' { return $null }
                default { Write-Host 'Invalid selection.' -ForegroundColor Yellow; Pause-RiD }
            }
        }
    } catch { Write-Error $_ }
    return $null
}
