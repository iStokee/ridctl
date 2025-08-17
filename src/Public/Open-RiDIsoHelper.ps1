function Open-RiDIsoHelper {
    <#
    .SYNOPSIS
        Guides the user through obtaining or selecting a Windows ISO.

    .DESCRIPTION
        Interactively prompts the user to specify whether an ISO is
        already available.  If so, opens a file selection dialog and
        validates the chosen file.  Otherwise offers to open the
        official Microsoft download page in the default browser or to
        invoke an automated download via the embedded Fido script (not
        yet implemented).  Returns the path to the ISO or `$null` if
        cancelled.
    #>
    [CmdletBinding()] param()

    Write-Host 'Windows ISO acquisition' -ForegroundColor Cyan
    Write-Host '----------------------' -ForegroundColor Cyan
    
    # Ask user if they already have an ISO
    $hasIso = Read-Host 'Do you already have a Windows ISO? [Y/N]'
    if ($hasIso -match '^[Yy]') {
        # Let user pick the file via open file dialog
        $path = Show-RiDOpenFileDialog -Filter 'ISO files (*.iso)|*.iso|All files (*.*)|*.*'
        if ($null -eq $path) {
            Write-Warning 'No file selected. Aborting ISO helper.'
            return $null
        }
        if (-not (Test-Path -Path $path)) {
            Write-Warning "The selected file does not exist: $path"
            return $null
        }
        if ([System.IO.Path]::GetExtension($path) -ne '.iso') {
            Write-Warning 'The selected file does not have an .iso extension.'
        }
        return $path
    }

    # Offer guided or automated download
    $choice = Read-Host 'ISO not found. Would you like a guided download [G], automated download [A] or cancel [C]?'
    switch ($choice.ToUpper()) {
        'G' {
            Write-Host 'Opening Microsoft Windows download page in your browser...' -ForegroundColor Cyan
            # Choose OS version
            $osChoice = Read-Host 'Which version do you need? [10/11]'
            switch ($osChoice) {
                '10' { $url = 'https://www.microsoft.com/software-download/windows10' }
                '11' { $url = 'https://www.microsoft.com/software-download/windows11' }
                default {
                    Write-Warning 'Invalid selection.'
                    return $null
                }
            }
            Open-RiDBrowser -Url $url
            Write-Host 'Follow the instructions on the Microsoft page to download the ISO. Once downloaded, run Open-RiDIsoHelper again and select the file.' -ForegroundColor Yellow
            return $null
        }
        'A' {
            # Automated path using Fido integration (if available)
            try {
                $ver = Read-Host 'Version [10/11] (default 11)'
                if ($ver -ne '10' -and $ver -ne '11') { $ver = '11' }
                $lang = Read-Host 'Language (e.g., en-US) [default en-US]'
                if (-not $lang) { $lang = 'en-US' }
                $cfg = Initialize-RiDConfig
                $dest = $null
                if ($cfg['Iso'] -and $cfg['Iso']['DefaultDownloadDir']) { $dest = $cfg['Iso']['DefaultDownloadDir'] }
                if (-not $dest) { $dest = Read-Host 'Download directory (leave blank for your Downloads folder)' }
                if (-not $dest) { $dest = [Environment]::GetFolderPath('UserProfile') + '\\Downloads' }
                $vparam = if ($ver -eq '10') { 'win10' } else { 'win11' }
                $tryNon = Read-Host 'Try non-interactive mode if supported? [y/N]'
                $trySwitch = ($tryNon -match '^[Yy]')
                if ($trySwitch) {
                    $adv = Read-Host 'Advanced selector? [Y/n]'
                    if ($adv -notmatch '^[Nn]') {
                        try {
                            # Interactive sub-menu powered by headless list APIs
                            $verList = Get-RiDFidoList -List Win
                            $verChoices = @('10','11')
                            if ($verList -and $verList -contains '8.1') { $verChoices = @('10','11') }
                            Write-Host 'Select Windows version:' -ForegroundColor Cyan
                            for ($i=0;$i -lt $verChoices.Count;$i++){ Write-Host ("  {0}) {1}" -f ($i+1), $verChoices[$i]) }
                            $sel = Read-Host 'Choice [default 2]'
                            $verNum = if ($sel -eq '1') { '10' } else { '11' }

                            $relList = Get-RiDFidoList -List Rel -Version $verNum
                            $relOpts = @('Latest') + $relList
                            Write-Host 'Select release:' -ForegroundColor Cyan
                            for ($i=0;$i -lt $relOpts.Count;$i++){ Write-Host ("  {0}) {1}" -f ($i+1), $relOpts[$i]) }
                            $sel = Read-Host 'Choice [default 1]'
                            $rel = if ($sel -and ($sel -as [int]) -ge 1 -and ($sel -as [int]) -le $relOpts.Count) { $relOpts[([int]$sel-1)] } else { 'Latest' }

                            $edList = Get-RiDFidoList -List Ed -Version $verNum -Release $rel
                            Write-Host 'Select edition:' -ForegroundColor Cyan
                            for ($i=0;$i -lt $edList.Count;$i++){ Write-Host ("  {0}) {1}" -f ($i+1), $edList[$i]) }
                            $sel = Read-Host 'Choice [default 1]'
                            $ed = if ($sel -and ($sel -as [int]) -ge 1 -and ($sel -as [int]) -le $edList.Count) { $edList[([int]$sel-1)] } else { $edList[0] }

                            $langList = Get-RiDFidoList -List Lang -Version $verNum -Release $rel -Edition $ed
                            Write-Host 'Select language:' -ForegroundColor Cyan
                            for ($i=0;$i -lt $langList.Count;$i++){ Write-Host ("  {0}) {1}" -f ($i+1), $langList[$i]) }
                            $sel = Read-Host 'Choice [default 1]'
                            $langSel = if ($sel -and ($sel -as [int]) -ge 1 -and ($sel -as [int]) -le $langList.Count) { $langList[([int]$sel-1)] } else { $langList[0] }

                            $archChoices = @('x64','arm64','x86')
                            Write-Host 'Select architecture:' -ForegroundColor Cyan
                            for ($i=0;$i -lt $archChoices.Count;$i++){ Write-Host ("  {0}) {1}" -f ($i+1), $archChoices[$i]) }
                            $sel = Read-Host 'Choice [default 1]'
                            $archSel = if ($sel -eq '2') { 'arm64' } elseif ($sel -eq '3') { 'x86' } else { 'x64' }

                            $cfg = Initialize-RiDConfig
                            if (-not $cfg['Iso']) { $cfg['Iso'] = @{} }
                            $cfg['Iso']['Release'] = $rel
                            $cfg['Iso']['Edition'] = $ed
                            $cfg['Iso']['Arch']    = $archSel
                            Set-RiDConfig -Config $cfg

                            # Override local variables for this run
                            $lang = $langSel
                            $ver = $verNum
                            $vparam = if ($ver -eq '10') { 'win10' } else { 'win11' }
                        } catch { Write-Error $_ }
                    }
                }
                if ($trySwitch) {
                    $cur = Initialize-RiDConfig
                    $rel = $cur['Iso']['Release']; $ed = $cur['Iso']['Edition']; $ar = $cur['Iso']['Arch']
                    Write-Host ("Using defaults: Release={0}, Edition={1}, Arch={2}" -f $rel,$ed,$ar) -ForegroundColor DarkCyan
                }
                $iso = Invoke-RiDFidoDownload -Version $vparam -Language $lang -Destination $dest -TryNonInteractive:$trySwitch
                if ($iso) { return $iso } else { return $null }
            } catch { Write-Error $_; return $null }
        }
        default {
            Write-Host 'Cancelling ISO helper.'
            return $null
        }
    }
}
