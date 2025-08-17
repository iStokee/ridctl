function Open-RiDGuestHelper {
    <#
    .SYNOPSIS
      Interactive helper for configuring guest software (7-Zip, Java, RiD, RuneScape).

    .DESCRIPTION
      Presents a submenu inside the guest to install/download common software:
      - 7-Zip (via winget/choco)
      - Java JRE (Temurin 17 JRE via winget/choco)
      - RiD archive: download and extract using Initialize-RiDGuest, or use pre-seeded archive
      - RuneScape (RS3/OSRS): download and launch installers (Launcher or Classic)

      Returns when the user exits.

    .EXAMPLE
      PS> Open-RiDGuestHelper
    #>
    [CmdletBinding()] param()

    try {
        # Preflight environment checks
        $prep = Ensure-RiDGuestPrereqs
        Write-Host ('Admin: {0} | winget: {1} | choco: {2} | BITS: {3} | TLS: {4}' -f $prep.Admin,$prep.WingetAvailable,$prep.ChocoAvailable,$prep.BitsAvailable,$prep.TlsSet) -ForegroundColor DarkGray
        if (-not $prep.Admin) { Write-Host 'Note: Some installers may require elevation. Run PowerShell as Administrator for best results.' -ForegroundColor Yellow }
        while ($true) {
            Clear-Host
            Write-RiDHeader -Title 'RiD Control > Guest Software Helper'
            Write-Host 'Choose an action:' -ForegroundColor Green
            Write-Host '  1) Install 7-Zip'
            Write-Host '  2) Install Java JRE (Temurin 17)'
            Write-Host '  3) Setup RiD (download/extract)'
            Write-Host '  4) Setup RiD from local archive (no download)'
            Write-Host '  5) RuneScape: Download and launch installer'
            Write-Host '  6) Install Chocolatey (package manager)'
            Write-Host '  7) Install/Update winget (App Installer)'
            Write-Host '  X) Back'
            $sel = Read-Host 'Select an option [1]'
            if (-not $sel) { $sel = '1' }

            switch ($sel.ToUpper()) {
                '1' {
                    try {
                        $ok = Install-RiD7Zip
                        if ($ok) { Write-Host '7-Zip installation requested.' -ForegroundColor Green } else { Write-Host '7-Zip installation could not be completed automatically.' -ForegroundColor Yellow }
                    } catch { Write-Error $_ }
                    Pause-RiD
                }
                '2' {
                    try {
                        $ok = Install-RiDJavaJre
                        if ($ok) { Write-Host 'Java JRE installation requested.' -ForegroundColor Green } else { Write-Host 'Java installation could not be completed automatically.' -ForegroundColor Yellow }
                    } catch { Write-Error $_ }
                    Pause-RiD
                }
                '3' {
                    try {
                        $dest = Read-Host ("Destination folder for RiD [{0}]" -f (Join-Path $env:USERPROFILE 'RiD'))
                        if (-not $dest) { $dest = (Join-Path $env:USERPROFILE 'RiD') }
                        $j = Read-Host 'Install Java as well? [y/N]'
                        Initialize-RiDGuest -InstallJava:($j -match '^[Yy]') -Destination $dest -Confirm:$true | Out-Null
                    } catch { Write-Error $_ }
                    Pause-RiD
                }
                '4' {
                    try {
                        $dest = Read-Host ("Destination folder for RiD [{0}]" -f (Join-Path $env:USERPROFILE 'RiD'))
                        if (-not $dest) { $dest = (Join-Path $env:USERPROFILE 'RiD') }
                        $arc = $null
                        try { $arc = Show-RiDOpenFileDialog -Filter 'RiD archive (*.zip;*.7z;*.rar)|*.zip;*.7z;*.rar|All files (*.*)|*.*' -Title 'Select RiD archive' } catch { }
                        if (-not $arc) { $arc = Read-Host 'Path to RiD archive (.rar/.7z/.zip)' }
                        if ($arc) { Initialize-RiDGuest -NoDownload -ArchivePath $arc -Destination $dest -Confirm:$true | Out-Null }
                        else { Write-Host 'No archive selected.' -ForegroundColor Yellow }
                    } catch { Write-Error $_ }
                    Pause-RiD
                }
                '5' {
                    try {
                        Write-Host 'RuneScape variants:' -ForegroundColor Cyan
                        Write-Host '  a) RS3 - Jagex Launcher (EXE)'
                        Write-Host '  b) RS3 - Classic installer (EXE)'
                        Write-Host '  c) OSRS - Jagex Launcher (EXE)'
                        Write-Host '  d) OSRS - Classic installer (MSI)'
                        $v = Read-Host 'Choose [a/b/c/d]'
                        $url = $null
                        switch ($v.ToLower()) {
                            'a' { $url = 'https://cdn.jagex.com/Jagex%20Launcher%20Installer.exe' }
                            'b' { $url = 'https://content.runescape.com/downloads/windows/RuneScape-Setup.exe' }
                            'c' { $url = 'https://cdn.jagex.com/Jagex%20Launcher%20Installer.exe' }
                            'd' { $url = 'https://www.runescape.com/downloads/oldschool.msi' }
                            default { }
                        }
                        if (-not $url) { $url = Read-Host 'Enter direct download URL for installer' }
                        if ($url) { Install-RiDRunescape -Url $url }
                        else { Write-Host 'No URL provided.' -ForegroundColor Yellow }
                    } catch { Write-Error $_ }
                    Pause-RiD
                }
                '6' {
                    try {
                        $ok = Install-RiDChocolatey
                        if ($ok) { Write-Host 'Chocolatey installed or already present.' -ForegroundColor Green }
                        else { Write-Host 'Chocolatey installation not completed. Ensure you are running as Administrator.' -ForegroundColor Yellow }
                    } catch { Write-Error $_ }
                    Pause-RiD
                }
                '7' {
                    try {
                        $ok = Install-RiDWinget
                        if ($ok) { Write-Host 'winget detected.' -ForegroundColor Green }
                        else { Write-Host 'Opened Microsoft Store/App Installer page. Complete install then re-run.' -ForegroundColor Yellow }
                    } catch { Write-Error $_ }
                    Pause-RiD
                }
                'X' { return }
                default { Write-Host 'Invalid selection.' -ForegroundColor Yellow; Pause-RiD }
            }
        }
    } catch { Write-Error $_ }
}
