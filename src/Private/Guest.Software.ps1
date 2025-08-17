<#
  Helpers for installing/downloading guest software.
  - Ensure-RiDGuestPrereqs prepares TLS and reports admin/winget/choco availability.
  - 7-Zip and Java JRE use winget or Chocolatey when available.
  - RuneScape installers are downloaded to the user's Downloads folder and launched.
#>

function Get-RiDGuestDownloadDir {
    [CmdletBinding()] param()
    try { return (Join-Path -Path $env:USERPROFILE -ChildPath 'Downloads') } catch { return $env:USERPROFILE }
}

function Test-RiDAdmin {
    [CmdletBinding()] param()
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        $p  = New-Object Security.Principal.WindowsPrincipal($id)
        return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function Ensure-RiDGuestPrereqs {
    [CmdletBinding()] param()
    $summary = [pscustomobject]@{
        Admin           = $false
        WingetAvailable = $false
        ChocoAvailable  = $false
        BitsAvailable   = $false
        DownloadDir     = $null
        TlsSet          = $false
    }
    # TLS 1.2+ for downloads on legacy PS5.1 environments
    try {
        $proto = [Net.ServicePointManager]::SecurityProtocol
        $new = [Net.SecurityProtocolType]::Tls12
        try { $new = $new -bor [Net.SecurityProtocolType]::Tls13 } catch { }
        [Net.ServicePointManager]::SecurityProtocol = $proto -bor $new
        $summary.TlsSet = $true
    } catch { }

    $summary.Admin = Test-RiDAdmin
    $summary.WingetAvailable = [bool](Get-Command -Name winget -ErrorAction SilentlyContinue)
    $summary.ChocoAvailable  = [bool](Get-Command -Name choco -ErrorAction SilentlyContinue)
    $summary.BitsAvailable   = [bool](Get-Command -Name Start-BitsTransfer -ErrorAction SilentlyContinue)
    $dir = Get-RiDGuestDownloadDir
    try { if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null } } catch { }
    $summary.DownloadDir = $dir
    return $summary
}

function Install-RiDChocolatey {
    [CmdletBinding()] param()
    if (-not (Test-RiDAdmin)) { Write-Warning 'Chocolatey installation requires an elevated PowerShell. Please run as Administrator.'; return $false }
    try {
        # Official bootstrap script from Chocolatey community site
        $env:CHOCOLATEYUSEWINDOWSCOMPATIBILITYMODE = 'true'
        Set-ExecutionPolicy Bypass -Scope Process -Force | Out-Null
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $script = (New-Object Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')
        Invoke-Expression $script
        # Refresh session detection
        return [bool](Get-Command -Name choco -ErrorAction SilentlyContinue)
    } catch { Write-Error $_; return $false }
}

function Install-RiDWinget {
    <#
      Best-effort installer for winget by invoking Microsoft Store App Installer page.
      Fully unattended offline install is non-trivial due to MSIX dependencies.
    #>
    [CmdletBinding()] param()
    try {
        if (Get-Command -Name winget -ErrorAction SilentlyContinue) { return $true }
        Write-Host 'Opening Microsoft Store to App Installer (provides winget)...' -ForegroundColor Cyan
        # App Installer Store product page
        $storeUri = 'ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1'
        try { Start-Process -FilePath $storeUri | Out-Null } catch { Write-Verbose $_ }
        # Web fallback landing page
        Open-RiDBrowser -Url 'https://aka.ms/getwinget'
        Write-Host 'After installing App Installer from Microsoft Store, re-run this helper to detect winget.' -ForegroundColor Yellow
        return $false
    } catch { Write-Error $_; return $false }
}

function Install-RiD7Zip {
    [CmdletBinding()] param()
    try {
        if (Get-Command -Name winget -ErrorAction SilentlyContinue) {
            $rc = _Invoke-Process -FilePath 'winget' -Arguments 'install --id 7zip.7zip -e --source winget --silent'
            if ($rc -eq 0) { return $true }
        }
    } catch {}
    try {
        if (Get-Command -Name choco -ErrorAction SilentlyContinue) {
            $rc = _Invoke-Process -FilePath 'choco' -Arguments 'install -y 7zip'
            if ($rc -eq 0) { return $true }
        }
    } catch {}
    Write-Warning 'Could not install 7-Zip automatically (winget/choco not available or failed).'
    return $false
}

function Install-RiDJavaJre {
    [CmdletBinding()] param()
    try {
        if (Get-Command -Name winget -ErrorAction SilentlyContinue) {
            $rc = _Invoke-Process -FilePath 'winget' -Arguments 'install -e --id EclipseAdoptium.Temurin.17.JRE --silent'
            if ($rc -eq 0) { return $true }
        }
    } catch {}
    try {
        if (Get-Command -Name choco -ErrorAction SilentlyContinue) {
            $rc = _Invoke-Process -FilePath 'choco' -Arguments 'install -y temurin17jre'
            if ($rc -eq 0) { return $true }
        }
    } catch {}
    Write-Warning 'Could not install Java JRE automatically (winget/choco not available or failed).'
    return $false
}

function Install-RiDRunescape {
    <#
      Downloads a RuneScape installer and launches it. URL may be any of:
        - RS3 Jagex Launcher: https://cdn.jagex.com/Jagex%20Launcher%20Installer.exe
        - RS3 Classic:        https://content.runescape.com/downloads/windows/RuneScape-Setup.exe
        - OSRS Jagex Launcher: same as above
        - OSRS Classic:       https://www.runescape.com/downloads/oldschool.msi
    #>
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)][string]$Url
    )
    try {
        $dir = Get-RiDGuestDownloadDir
        $name = Split-Path -Path $Url -Leaf
        if (-not $name) { $name = ('RuneScape-' + (Get-Random) + '.exe') }
        $out = Join-Path -Path $dir -ChildPath $name
        Write-Host ("Downloading installer to {0}..." -f $out) -ForegroundColor Cyan
        $dl = Invoke-RiDDownload -Uri $Url -OutFile $out -MinExpectedMB 1
        if (-not $dl) { Write-Error 'Download failed.'; return $false }
        Write-Host 'Launching installer...' -ForegroundColor Cyan
        # Determine silent args for MSI; otherwise launch interactively
        $ext = [IO.Path]::GetExtension($out).ToLowerInvariant()
        if ($ext -eq '.msi') {
            $rc = _Invoke-Process -FilePath 'msiexec.exe' -Arguments ('/i "{0}" /qn' -f $out)
            if ($rc -ne 0) { Write-Warning ("msiexec exited with code {0}; you may need to run interactively." -f $rc) }
        } else {
            try { Start-Process -FilePath $out -ArgumentList '' -WindowStyle Normal | Out-Null } catch { Write-Error $_; return $false }
        }
        return $true
    } catch { Write-Error $_; return $false }
}

function Test-RiD7ZipPresent {
    [CmdletBinding()] param()
    try {
        if (Get-Command -Name 7z.exe -ErrorAction SilentlyContinue) { return $true }
        $candidates = @('C:\\Program Files\\7-Zip\\7z.exe','C:\\Program Files (x86)\\7-Zip\\7z.exe')
        foreach ($p in $candidates) { if (Test-Path -LiteralPath $p) { return $true } }
    } catch { }
    return $false
}

function Test-RiDJavaPresent {
    [CmdletBinding()] param()
    try {
        $java = (Get-Command -Name java.exe -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($java) { return $true }
        $paths = @(
            (Join-Path $env:ProgramFiles 'Eclipse Adoptium')
            ,(Join-Path ${env:ProgramFiles(x86)} 'Eclipse Adoptium')
        ) | Where-Object { $_ }
        foreach ($root in $paths) {
            if (Test-Path -LiteralPath $root) {
                $javaExe = Get-ChildItem -LiteralPath $root -Recurse -Filter java.exe -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($javaExe) { return $true }
            }
        }
    } catch { }
    return $false
}

function Test-RiDRiDInstalled {
    [CmdletBinding()] param()
    try {
        $default = Join-Path $env:USERPROFILE 'RiD'
        return (Test-Path -LiteralPath $default)
    } catch { return $false }
}
