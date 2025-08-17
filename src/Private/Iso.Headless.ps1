<#
    Headless wrapper around upstream Fido.ps1 to obtain Microsoft retail
    Windows ISO URLs and optionally download the ISO using BITS or the
    module streaming downloader.
#>

function Ensure-RiDFidoScript {
    [CmdletBinding()] param()
    $path = Get-RiDFidoScriptPath
    if ($path -and (Test-Path -LiteralPath $path)) {
        # If legacy Get-WindowsIso.ps1 is present but Fido.ps1 missing, install Fido.ps1 in same dir
        try {
            $dir = Split-Path -Path $path -Parent
            $fidoCanon = Join-Path -Path $dir -ChildPath 'Fido.ps1'
            if (-not (Test-Path -LiteralPath $fidoCanon)) {
                $null = Install-RiDFido -DestinationDir $dir -PersistConfig -Apply
                if (Test-Path -LiteralPath $fidoCanon) { return $fidoCanon }
            }
        } catch { }
        return $path
    }
    $installed = Install-RiDFido -PersistConfig -Apply
    if ($installed -and (Test-Path -LiteralPath $installed)) { return $installed }
    return $null
}

function Get-RiDHeadlessWrapperPath {
    [CmdletBinding()] param()
    # Preferred wrapper filename we generate: RiD-GetWindowsIso.ps1
    $fido = Ensure-RiDFidoScript
    if (-not $fido) { return $null }
    $dir = Split-Path -Path $fido -Parent
    $ridWrapper = Join-Path -Path $dir -ChildPath 'RiD-GetWindowsIso.ps1'
    # Always (re)write wrapper to ensure latest logic
    try {
@'
param()
$scriptDir = Split-Path -Parent -Path $MyInvocation.MyCommand.Path
if (-not $scriptDir) { $scriptDir = (Resolve-Path '.').Path }
$Script:FidoPath = Join-Path $scriptDir 'Fido.ps1'
function Invoke-FidoInternal([string]$Arguments) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = (Get-Command powershell.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1)
    if (-not $psi.FileName) { $psi.FileName = (Get-Command pwsh -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1) }
    if (-not $psi.FileName) { $psi.FileName = 'powershell.exe' }
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$Script:FidoPath`" $Arguments"
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $p = [System.Diagnostics.Process]::Start($psi)
    $out = $p.StandardOutput.ReadToEnd()
    $err = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    if ($p.ExitCode -ne 0 -and $err) { Write-Verbose $err }
    return ($out -replace '\r','').Trim()
}

function Get-WindowsIso {
    [CmdletBinding(DefaultParameterSetName='Download')]
    param(
        [Parameter(ParameterSetName='Download')][Parameter(ParameterSetName='UrlOnly')][Parameter(ParameterSetName='List')]
        [ValidateSet('8.1','10','11')] [string]$Version = '11',
        [Parameter(ParameterSetName='Download')][Parameter(ParameterSetName='UrlOnly')][Parameter(ParameterSetName='List')]
        [string]$Release = 'Latest',
        [Parameter(ParameterSetName='Download')][Parameter(ParameterSetName='UrlOnly')][Parameter(ParameterSetName='List')]
        [string]$Edition = 'Home/Pro',
        [Parameter(ParameterSetName='Download')][Parameter(ParameterSetName='UrlOnly')][Parameter(ParameterSetName='List')]
        [string]$Language = 'English International',
        [Parameter(ParameterSetName='Download')][Parameter(ParameterSetName='UrlOnly')][Parameter(ParameterSetName='List')]
        [ValidateSet('x64','x86','arm64')] [string]$Arch = 'x64',
        [Parameter(ParameterSetName='Download', Mandatory)] [string]$OutFile,
        [Parameter(ParameterSetName='UrlOnly')] [switch]$GetUrl,
        [Parameter(ParameterSetName='List')][ValidateSet('Win','Rel','Ed','Lang')] [string]$List
    )
    if ($PSCmdlet.ParameterSetName -eq 'List') {
        switch ($List) {
            'Win'  { $args = '-Win List' }
            'Rel'  { $args = "-Win $Version -Rel List" }
            'Ed'   { $args = "-Win $Version -Rel $Release -Ed List" }
            'Lang' { $args = "-Win $Version -Rel $Release -Ed `"$Edition`" -Lang List" }
        }
        return (Invoke-FidoInternal $args)
    }
    $base = "-Win $Version -Rel $Release -Ed `"$Edition`" -Lang `"$Language`" -Arch $Arch"
    if ($GetUrl) { return (Invoke-FidoInternal ($base + ' -GetUrl')) }
    $dir = Split-Path -Path $OutFile -Parent
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $url = Invoke-FidoInternal ($base + ' -GetUrl')
    if (-not $url) { throw 'Failed to obtain URL from Fido.' }
    try { Start-BitsTransfer -Source $url -Destination $OutFile -ErrorAction Stop }
    catch { Invoke-WebRequest -Uri $url -OutFile $OutFile -UseBasicParsing }
    if (-not (Test-Path $OutFile)) { throw "Download failed: $OutFile not found." }
    $size = (Get-Item $OutFile).Length
    if ($size -lt 1GB) { throw "Download appears incomplete (size: $size bytes)." }
    return $OutFile
}
'@ | Out-File -LiteralPath $ridWrapper -Encoding UTF8 -Force
    } catch { return $null }
    return $ridWrapper
}

function Invoke-RiDFidoCli {
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)][string]$Arguments
    )
    $fido = Ensure-RiDFidoScript
    if (-not $fido) { throw 'Fido script is not available.' }
    $psExe = (Get-Command powershell.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1)
    if (-not $psExe) { $psExe = (Get-Command pwsh.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1) }
    if (-not $psExe) { $psExe = 'powershell.exe' }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $psExe
    $psi.Arguments = ('-NoProfile -ExecutionPolicy Bypass -File "{0}" {1}' -f $fido, $Arguments)
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $p = [System.Diagnostics.Process]::Start($psi)
    $out = $p.StandardOutput.ReadToEnd()
    $err = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    if ($p.ExitCode -ne 0 -and $err) { Write-Verbose $err }
    return ($out -replace '\r','').Trim()
}

function Get-RiDWindowsIso {
    <#
      Headless Windows ISO: returns URL or downloads file.
    #>
    [CmdletBinding(DefaultParameterSetName='UrlOnly')]
    param(
        [Parameter()][ValidateSet('8.1','10','11')][string]$Version = '11',
        [Parameter()][string]$Release = 'Latest',
        [Parameter()][string]$Edition = 'Home/Pro',
        [Parameter()][string]$Language = 'English International',
        [Parameter()][ValidateSet('x64','x86','arm64')][string]$Arch = 'x64',
        [Parameter(ParameterSetName='Download')][string]$OutFile,
        [Parameter(ParameterSetName='UrlOnly')][switch]$GetUrl
    )
    $wrapper = Get-RiDHeadlessWrapperPath
    if (-not $wrapper) { return $null }
    $args = ('-Version {0} -Release {1} -Edition "{2}" -Language "{3}" -Arch {4}' -f $Version, $Release, $Edition, $Language, $Arch)
    # Run the wrapper script with a clean PowerShell process
    $psExe = (Get-Command powershell.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1)
    if (-not $psExe) { $psExe = (Get-Command pwsh -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1) }
    if (-not $psExe) { $psExe = 'powershell.exe' }
    $argLine = ('-NoProfile -ExecutionPolicy Bypass -File "{0}" {1}' -f $wrapper, $args)
    if ($GetUrl) { $argLine += ' -GetUrl' }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $psExe
    $psi.Arguments = $argLine
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $p = [System.Diagnostics.Process]::Start($psi)
    $out = $p.StandardOutput.ReadToEnd()
    $err = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    $text = ($out -replace '\r','').Trim()
    if ($GetUrl) { return $text }
    if (-not $OutFile) { throw 'OutFile is required when not using -GetUrl.' }
    if (-not $text -or -not ($text -match '^https?://')) { return $null }
    try {
        $dl = Invoke-RiDDownload -Uri $text -OutFile $OutFile -MinExpectedMB 1000
        return $dl
    } catch { Write-Error $_; return $null }
}

function Get-RiDFidoList {
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)][ValidateSet('Win','Rel','Ed','Lang')] [string]$List,
        [Parameter()][string]$Version = '11',
        [Parameter()][string]$Release = 'Latest',
        [Parameter()][string]$Edition = 'Home/Pro'
    )
    $wrapper = Get-RiDHeadlessWrapperPath
    if (-not $wrapper) { return @() }
    $psExe = (Get-Command powershell.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1)
    if (-not $psExe) { $psExe = (Get-Command pwsh -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1) }
    if (-not $psExe) { $psExe = 'powershell.exe' }
    $args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f $wrapper))
    switch ($List) {
        'Win'  { $args += @('-List','Win') }
        'Rel'  { $args += @('-Version', $Version, '-List','Rel') }
        'Ed'   { $args += @('-Version', $Version, '-Release', $Release, '-List','Ed') }
        'Lang' { $args += @('-Version', $Version, '-Release', $Release, '-Edition', ('"{0}"' -f $Edition), '-List','Lang') }
    }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $psExe
    $psi.Arguments = ($args -join ' ')
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $p = [System.Diagnostics.Process]::Start($psi)
    $out = $p.StandardOutput.ReadToEnd()
    $p.WaitForExit()
    if (-not $out) { return @() }
    return ($out -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}
