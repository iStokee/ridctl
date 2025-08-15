<#
    Fido integration wrapper for automated Windows ISO acquisition.
    We do not vendor Fido in this repository. Instead, we look for a
    local Fido script (configurable) and launch it to acquire the ISO.
    After download completes, we prompt the user to select the ISO file
    under the destination directory and return its path.
    
    Configuration (optional):
      Iso.FidoScriptPath   -> Full path to Fido script (Get-WindowsIso.ps1)
      Iso.DefaultDownloadDir -> Default directory to suggest for downloads
#>

function Get-RiDFidoScriptPath {
    [CmdletBinding()] param()
    $cfg = Get-RiDConfig
    if ($cfg.Iso -and $cfg.Iso.FidoScriptPath -and (Test-Path -Path $cfg.Iso.FidoScriptPath)) {
        return $cfg.Iso.FidoScriptPath
    }
    # Default: third_party\fido\Get-WindowsIso.ps1 relative to repo root
    $privateDir = $PSScriptRoot
    $moduleRoot = Split-Path -Path $privateDir -Parent  # src
    $repoRoot   = Split-Path -Path $moduleRoot -Parent
    $default = Join-Path -Path $repoRoot -ChildPath 'third_party\fido\Get-WindowsIso.ps1'
    if (Test-Path -Path $default) { return $default }
    return $null
}

function Invoke-RiDFidoDownload {
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)][ValidateSet('win10','win11')] [string]$Version,
        [Parameter(Mandatory=$true)] [string]$Language,
        [Parameter(Mandatory=$true)] [string]$Destination,
        [Parameter()] [switch]$TryNonInteractive
    )
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
    Write-Host ("Suggested download directory: {0}" -f $Destination) -ForegroundColor Cyan

    $started = $false
    if ($TryNonInteractive) {
        # Structured non-interactive using known Fido params
        $cfg = Get-RiDConfig
        $winName = if ($Version -eq 'win10') { 'Windows 10' } else { 'Windows 11' }
        $release = $null
        $edition = $null
        $arch    = $null
        if ($cfg.Iso -and $cfg.Iso.Release) { $release = [string]$cfg.Iso.Release }
        if ($cfg.Iso -and $cfg.Iso.Edition) { $edition = [string]$cfg.Iso.Edition }
        if ($cfg.Iso -and $cfg.Iso.Arch)    { $arch    = [string]$cfg.Iso.Arch }
        if (-not $release) { $release = if ($Version -eq 'win10') { '22H2' } else { '23H2' } }
        if (-not $edition) { $edition = 'Pro' }
        if (-not $arch)    { $arch    = 'x64' }

        $tempOut = Join-Path -Path $Destination -ChildPath ('fido_url_{0}.txt' -f ([guid]::NewGuid().ToString('N')))
        $argList = @(
            '-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f $fido),
            '-Win',('"{0}"' -f $winName),
            '-Rel',('"{0}"' -f $release),
            '-Ed', ('"{0}"' -f $edition),
            '-Lang', ('"{0}"' -f $Language),
            '-Arch', ('"{0}"' -f $arch),
            '-GetUrl'
        )
        try {
            Write-Host ("[fido] Trying non-interactive mode: {0} {1} {2}/{3}/{4}" -f $winName, $release, $edition, $Language, $arch) -ForegroundColor Cyan
            $proc = Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -RedirectStandardOutput $tempOut -PassThru -WindowStyle Hidden -WorkingDirectory $Destination -ErrorAction Stop
            $null = $proc.WaitForExit()
            $started = $true
            $url = $null
            if (Test-Path -Path $tempOut) {
                $content = Get-Content -Path $tempOut -Raw -ErrorAction SilentlyContinue
                if ($content) {
                    $m = [regex]::Matches($content, 'https?://\S+')
                    if ($m.Count -gt 0) { $url = $m[0].Value.Trim() }
                }
                Remove-Item -Path $tempOut -ErrorAction SilentlyContinue
            }
            if ($url) {
                Write-Host ("[fido] Download URL: {0}" -f $url) -ForegroundColor DarkCyan
                # Download ISO
                try {
                    $fileName = [System.IO.Path]::GetFileName(((New-Object System.Uri $url).AbsolutePath))
                    if (-not $fileName -or [IO.Path]::GetExtension($fileName).ToLowerInvariant() -ne '.iso') {
                        $fileName = 'Windows.iso'
                    }
                    $outFile = Join-Path -Path $Destination -ChildPath $fileName
                    Write-Host ("[fido] Downloading ISO to {0} ..." -f $outFile) -ForegroundColor Cyan
                    Invoke-WebRequest -Uri $url -OutFile $outFile -UseBasicParsing -ErrorAction Stop
                    return $outFile
                } catch {
                    Write-Warning ("Failed to download ISO automatically: {0}" -f $_)
                }
            } else {
                Write-Warning '[fido] Non-interactive run did not produce a URL.'
            }
        } catch {
            Write-Warning ("Non-interactive Fido attempt failed: {0}" -f $_)
        }
    }

    if (-not $started) {
        Write-Host 'A new PowerShell window may appear; follow its prompts to obtain the ISO link and download.' -ForegroundColor Yellow
        try {
            Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f $fido)) -WindowStyle Normal -WorkingDirectory $Destination | Out-Null
        } catch {
            Write-Warning ("Failed to start Fido script: {0}" -f $_)
            return $null
        }
    }

    # After the user completes download, prompt or auto-detect the ISO in the destination
    $initialDir = if (Test-Path -Path $Destination) { $Destination } else { $env:USERPROFILE }
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
