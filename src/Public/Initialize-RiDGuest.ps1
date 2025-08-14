function Initialize-RiDGuest {
    <#
    .SYNOPSIS
        Configures a Windows guest VM for RiD: installs 7-Zip, optionally Java, then downloads and extracts the RiD archive.

    .DESCRIPTION
        Intended to run inside a Windows guest VM. Attempts to install 7-Zip via winget or Chocolatey, optionally installs Java,
        downloads the RiD `.rar` archive (from parameter or configured default), and extracts it to the chosen destination using 7-Zip.
        Prompts are provided for key choices; non-interactive parameters are also available.

    .PARAMETER RiDUrl
        URL to the RiD archive (.rar). If not provided, the function uses config `RiDDownloadUrl` or a built-in default.

    .PARAMETER Destination
        Destination directory for extracted RiD files. Defaults to `$env:USERPROFILE\RiD`.

    .PARAMETER InstallJava
        If specified, attempts to install Java via winget or Chocolatey.

    .PARAMETER Force
        Overwrite destination if it exists (re-extract).

    .EXAMPLE
        PS> Initialize-RiDGuest -InstallJava

        Installs 7-Zip, installs Java if possible, downloads RiD and extracts it to the default destination.
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter()] [string]$RiDUrl,
        [Parameter()] [string]$Destination = (Join-Path $env:USERPROFILE 'RiD'),
        [Parameter()] [switch]$InstallJava,
        [Parameter()] [switch]$Force
    )

    # Ensure we are inside a VM (best-effort)
    if (-not (Get-RiDHostGuestInfo)) {
        Write-Warning 'Initialize-RiDGuest is intended to run inside a guest VM. Continuing anyway.'
    }

    # Determine RiD download URL
    if (-not $RiDUrl) {
        $cfg = Get-RiDConfig
        $RiDUrl = $cfg['RiDDownloadUrl']
        if (-not $RiDUrl) {
            $RiDUrl = 'https://www.robotzindisguise.com/g983njfg89Ahfh3q0afljf9ja0rokr3-1rjioRAJ93m/RiD.rar'
        }
    }

    # Ensure destination exists/ready
    if (Test-Path -Path $Destination) {
        if (-not $Force) {
            Write-Host ("Destination already exists: {0}" -f $Destination) -ForegroundColor Yellow
        } else {
            try { Remove-Item -Path $Destination -Recurse -Force -ErrorAction Stop } catch {}
        }
    }
    if (-not (Test-Path -Path $Destination)) { New-Item -ItemType Directory -Path $Destination -Force | Out-Null }

    # Ensure 7-Zip is installed (7z.exe)
    $sevenZip = _Find-7Zip
    if (-not $sevenZip) {
        Write-Host '7-Zip not found. Attempting installation...' -ForegroundColor Cyan
        if (-not (_Install-7Zip)) {
            Write-Error 'Failed to install 7-Zip automatically. Please install 7-Zip and re-run.'
            return 1
        }
        $sevenZip = _Find-7Zip
        if (-not $sevenZip) { Write-Error '7z.exe still not found after installation.'; return 1 }
    }

    # Optionally install Java
    if ($InstallJava) {
        Write-Host 'Attempting to install Java (Temurin JRE) via winget/choco...' -ForegroundColor Cyan
        _Install-Java | Out-Null
    }

    # Download RiD archive
    $tempFile = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('RiD_' + [System.Guid]::NewGuid().ToString('N') + '.rar')
    Write-Host ("Downloading RiD archive from {0}..." -f $RiDUrl) -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri $RiDUrl -OutFile $tempFile -UseBasicParsing -ErrorAction Stop
    } catch {
        Write-Error ("Failed to download RiD archive: {0}" -f $_)
        return 1
    }

    # Extract with 7z
    Write-Host ("Extracting RiD to {0}..." -f $Destination) -ForegroundColor Cyan
    $args = @('x', '"{0}"' -f $tempFile, '-o"{0}"' -f $Destination, '-y')
    try {
        $exit = _Invoke-Process -FilePath $sevenZip -Arguments ($args -join ' ')
        if ($exit -ne 0) { Write-Error ("7z exited with code {0}" -f $exit); return $exit }
    } catch {
        Write-Error ("Failed to extract RiD: {0}" -f $_)
        return 1
    } finally {
        try { Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue } catch {}
    }

    Write-Host 'RiD guest initialization complete.' -ForegroundColor Green
    return 0
}

function _Find-7Zip {
    $candidates = @(
        (Get-Command -Name 7z.exe -ErrorAction SilentlyContinue | Select-Object -First 1 | ForEach-Object Source),
        'C:\\Program Files\\7-Zip\\7z.exe',
        'C:\\Program Files (x86)\\7-Zip\\7z.exe'
    ) | Where-Object { $_ }
    foreach ($p in $candidates) { if (Test-Path -Path $p) { return $p } }
    return $null
}

function _Install-7Zip {
    # Try winget
    try {
        if (Get-Command -Name winget -ErrorAction SilentlyContinue) {
            $exit = _Invoke-Process -FilePath 'winget' -Arguments 'install --id 7zip.7zip -e --source winget --silent'
            if ($exit -eq 0) { return $true }
        }
    } catch {}
    # Try Chocolatey
    try {
        if (Get-Command -Name choco -ErrorAction SilentlyContinue) {
            $exit = _Invoke-Process -FilePath 'choco' -Arguments 'install -y 7zip'
            if ($exit -eq 0) { return $true }
        }
    } catch {}
    Write-Warning 'Automatic installation of 7-Zip failed. Please install 7-Zip manually.'
    return $false
}

function _Install-Java {
    # Prefer winget Temurin JRE (LTS). If winget unavailable, try Chocolatey.
    try {
        if (Get-Command -Name winget -ErrorAction SilentlyContinue) {
            $exit = _Invoke-Process -FilePath 'winget' -Arguments 'install -e --id EclipseAdoptium.Temurin.17.JRE --silent'
            if ($exit -eq 0) { return $true }
        }
    } catch {}
    try {
        if (Get-Command -Name choco -ErrorAction SilentlyContinue) {
            $exit = _Invoke-Process -FilePath 'choco' -Arguments 'install -y temurin17jre'
            if ($exit -eq 0) { return $true }
        }
    } catch {}
    Write-Warning 'Automatic installation of Java failed or is unavailable. You can install a JRE manually.'
    return $false
}

function _Invoke-Process {
    param([Parameter(Mandatory=$true)][string]$FilePath, [Parameter()][string]$Arguments)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = $Arguments
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute = $false
    $p = [System.Diagnostics.Process]::Start($psi)
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    if ($stdout) { Write-Verbose $stdout }
    if ($p.ExitCode -ne 0 -and $stderr) { Write-Verbose $stderr }
    return $p.ExitCode
}

