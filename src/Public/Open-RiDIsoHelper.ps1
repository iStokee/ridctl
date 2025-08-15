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
                $cfg = Get-RiDConfig
                $dest = $null
                if ($cfg.Iso -and $cfg.Iso.DefaultDownloadDir) { $dest = $cfg.Iso.DefaultDownloadDir }
                if (-not $dest) { $dest = Read-Host 'Download directory (leave blank for your Downloads folder)' }
                if (-not $dest) { $dest = [Environment]::GetFolderPath('UserProfile') + '\\Downloads' }
                $vparam = if ($ver -eq '10') { 'win10' } else { 'win11' }
                $tryNon = Read-Host 'Try non-interactive mode if supported? [y/N]'
                $trySwitch = ($tryNon -match '^[Yy]')
                if ($trySwitch) {
                    $adv = Read-Host 'Advanced options? (Release/Edition/Arch) [Y/n]'
                    if ($adv -notmatch '^[Nn]') {
                        $rel = Read-Host ("Release (default: {0})" -f (if ($vparam -eq 'win10') { '22H2' } else { '23H2' }))
                        $ed  = Read-Host 'Edition (default: Pro)'
                        $arch= Read-Host 'Architecture (default: x64)'
                        $cfg = Get-RiDConfig
                        if (-not $cfg.Iso) { $cfg.Iso = @{} }
                        if ($rel) { $cfg.Iso.Release = $rel }
                        if ($ed)  { $cfg.Iso.Edition = $ed }
                        if ($arch){ $cfg.Iso.Arch    = $arch }
                        if ($rel -or $ed -or $arch) { Set-RiDConfig -Config $cfg }
                    }
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
