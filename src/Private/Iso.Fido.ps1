<#
    Fido integration wrapper for automated Windows ISO acquisition.
    We do not vendor Fido in this repository. Instead, we look for a
    local Fido script (configurable) and launch it to acquire the ISO.
    After download completes, we prompt the user to select the ISO file
    under the destination directory and return its path.
    
    Configuration (optional):
      Iso.FidoScriptPath   -> Full path to Fido script (Fido.ps1 or Get-WindowsIso.ps1)
      Iso.DefaultDownloadDir -> Default directory to suggest for downloads
#>

function Get-RiDFidoScriptPath {
    [CmdletBinding()] param()
    $cfg = Get-RiDConfig
    if ($cfg['Iso'] -and $cfg['Iso']['FidoScriptPath'] -and (Test-Path -Path $cfg['Iso']['FidoScriptPath'])) {
        return $cfg['Iso']['FidoScriptPath']
    }
    # Default: third_party\fido\Fido.ps1 (preferred) relative to repo root; fallback to Get-WindowsIso.ps1
    $privateDir = $PSScriptRoot
    $moduleRoot = Split-Path -Path $privateDir -Parent  # src
    $repoRoot   = Split-Path -Path $moduleRoot -Parent
    $default = Join-Path -Path $repoRoot -ChildPath 'third_party\fido\Fido.ps1'
    if (Test-Path -Path $default) { return $default }
    $fallback = Join-Path -Path $repoRoot -ChildPath 'third_party\fido\Get-WindowsIso.ps1'
    if (Test-Path -Path $fallback) { return $fallback }
    return $null
}

function Invoke-RiDFidoDownload {
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)][ValidateSet('win10','win11')] [string]$Version,
        [Parameter(Mandatory=$true)] [string]$Language,
        [Parameter(Mandatory=$true)] [string]$Destination,
        [Parameter()] [switch]$TryNonInteractive
    )
    # Coerce destination to a usable string path
    if ($Destination -is [System.Collections.IDictionary]) {
        if ($Destination.ContainsKey('DefaultDownloadDir')) { $Destination = [string]$Destination['DefaultDownloadDir'] }
        else { $Destination = [string]$Destination }
    }
    if (-not $Destination) {
        try { $Destination = Join-Path -Path $env:USERPROFILE -ChildPath 'Downloads' } catch { $Destination = $env:USERPROFILE }
    }
    # Ensure destination exists
    if (-not (Test-Path -Path $Destination)) {
        try { New-Item -ItemType Directory -Path $Destination -Force | Out-Null } catch {}
    }

    $fido = Get-RiDFidoScriptPath
    if (-not $fido) {
        Write-Warning 'Fido script not found.'
        $install = Read-Host 'Install Fido now from official source? [Y/n]'
        if ($install -notmatch '^[Nn]') {
            $installed = Install-RiDFido -PersistConfig -Apply
            if ($installed -and (Test-Path -Path $installed)) { $fido = $installed }
        }
        if (-not $fido) {
            Write-Host 'Aborting automated ISO path; use Guided download or configure Fido path in config.' -ForegroundColor Yellow
            return $null
        }
    }

    Write-Host ("Launching Fido to acquire Windows ISO (Version: {0}, Language: {1})." -f $Version, $Language) -ForegroundColor Cyan
    Write-Host ("Suggested download directory: {0}" -f ([string]$Destination)) -ForegroundColor Cyan

    $started = $false
    $downloadedPath = $null
    if ($TryNonInteractive) {
        # Use headless wrapper based on upstream Fido CLI
        $cfg = Initialize-RiDConfig
        $vnum = if ($Version -eq 'win10') { '10' } else { '11' }
        $release = if ($cfg['Iso'] -and $cfg['Iso']['Release']) { [string]$cfg['Iso']['Release'] } else { 'Latest' }
        $edition = if ($cfg['Iso'] -and $cfg['Iso']['Edition']) { [string]$cfg['Iso']['Edition'] } else { 'Home/Pro' }
        $arch    = if ($cfg['Iso'] -and $cfg['Iso']['Arch'])    { [string]$cfg['Iso']['Arch'] }    else { 'x64' }
        # Language mapping from locale codes to Fido names
        $langName = $Language
        if ($langName -match '^(en|en-US)$') { $langName = 'English International' }
        Write-Host ("[fido] Trying headless mode: Win={0}, Rel={1}, Ed={2}, Lang={3}, Arch={4}" -f $vnum,$release,$edition,$langName,$arch) -ForegroundColor Cyan
        try {
            # Pick an output filename if we end up downloading
            $ts = (Get-Date).ToString('yyyyMMdd_HHmmss')
            $suggest = Join-Path -Path $Destination -ChildPath ("Win{0}_{1}_{2}_{3}.iso" -f $vnum,($langName -replace '\\s+',''),$arch,$ts)
            $url = Get-RiDWindowsIso -Version $vnum -Release $release -Edition $edition -Language $langName -Arch $arch -GetUrl
            if ($url -and $url -match '^https?://') {
                Write-Host ("[fido] Download URL: {0}" -f $url) -ForegroundColor DarkCyan
                $dl = Invoke-RiDDownload -Uri $url -OutFile $suggest -MinExpectedMB 1000
                if ($dl) { $downloadedPath = $dl } else { Write-Warning 'Automatic download failed.' }
                $started = $true
            } else {
                Write-Warning '[fido] Headless run did not produce a direct URL.'
            }
        } catch {
            Write-Warning ("Headless Fido attempt failed: {0}" -f $_)
        }
    }

    if (-not $started -or -not $downloadedPath) {
        Write-Host 'Launching the Fido window; complete the prompts to obtain the download link and start the ISO download.' -ForegroundColor Yellow
        # Capture baseline ISOs in destination
        $baseline = @()
        try { $baseline = Get-ChildItem -Path $Destination -Filter '*.iso' -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName } } catch { $baseline = @() }
        try {
            $psExe = (Get-Command powershell.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1)
            if (-not $psExe) { $psExe = (Get-Command pwsh.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1) }
            if (-not $psExe) { $psExe = 'powershell.exe' }
            Start-Process -FilePath $psExe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f $fido)) -WindowStyle Normal -WorkingDirectory $Destination | Out-Null
        } catch {
            Write-Warning ("Failed to start Fido script: {0}" -f $_)
            return $null
        }
        $watch = Read-Host ("Watch '{0}' for a new ISO and auto-select when found? [Y/n]" -f $Destination)
        if ($watch -notmatch '^[Nn]') {
            $timeoutSec = 1800
            $intervalSec = 5
            $elapsed = 0
            while ($elapsed -lt $timeoutSec) {
                try {
                    $isosNow = Get-ChildItem -Path $Destination -Filter '*.iso' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
                    foreach ($fi in $isosNow) {
                        if ($baseline -notcontains $fi.FullName) {
                            if ($fi.Length -gt 1GB) {
                                Write-Host ("Detected new ISO: {0}" -f $fi.FullName) -ForegroundColor Cyan
                                return $fi.FullName
                            }
                        }
                    }
                } catch { }
                Start-Sleep -Seconds $intervalSec
                $elapsed += $intervalSec
            }
            Write-Host 'Timeout watching for ISO; opening file picker...' -ForegroundColor Yellow
        }
    }

    # After the user completes download, prompt or auto-detect the ISO in the destination
    $initialDir = if (Test-Path -Path $Destination) { $Destination } else { $env:USERPROFILE }
    if ($downloadedPath -and (Test-Path -Path $downloadedPath)) { return $downloadedPath }
    $isos = Get-ChildItem -Path $initialDir -Filter '*.iso' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    if ($TryNonInteractive -and $isos -and $isos.Count -gt 0) {
        $latest = $isos[0].FullName
        $useLatest = Read-Host ("Detected latest ISO: `"{0}`". Use this file? [Y/n]" -f $latest)
        if ($useLatest -notmatch '^[Nn]') { return $latest }
    }
    Write-Host 'Select the ISO file to continue.' -ForegroundColor Cyan
    $isoPath = Show-RiDOpenFileDialog -InitialDirectory $initialDir -Filter 'ISO files (*.iso)|*.iso|All files (*.*)|*.*' -Title 'Select Windows ISO'
    if (-not $isoPath) { return $null }
    if (-not (Test-Path -Path $isoPath)) { Write-Warning "Selected path not found: $isoPath"; return $null }
    if ([IO.Path]::GetExtension($isoPath).ToLowerInvariant() -ne '.iso') { Write-Warning 'Selected file does not appear to be an ISO.' }
    return $isoPath
}
