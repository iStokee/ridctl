<#
    Helpers to acquire the Fido PowerShell script used for automated
    Windows ISO downloads. The helper downloads the script from a
    trusted upstream and stores it under third_party\fido, and can also
    persist the location into user config for reuse.
#>

function Install-RiDFido {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter()] [string]$DestinationDir,
        [Parameter()] [string]$SourceUrl = 'https://raw.githubusercontent.com/pbatard/Fido/refs/heads/master/Fido.ps1',
        [Parameter()] [switch]$PersistConfig,
        [Parameter()] [switch]$Apply
    )
    # Default destination under repo third_party\fido
    if (-not $DestinationDir) {
        $privateDir = $PSScriptRoot
        $moduleRoot = Split-Path -Path $privateDir -Parent  # src
        $repoRoot   = Split-Path -Path $moduleRoot -Parent
        $DestinationDir = Join-Path -Path $repoRoot -ChildPath 'third_party\fido'
    }
    $targetPath = Join-Path -Path $DestinationDir -ChildPath 'Get-WindowsIso.ps1'

    if (-not $Apply) {
        Write-Host ("[fido] Would download from {0} -> {1}" -f $SourceUrl, $targetPath) -ForegroundColor DarkCyan
        if ($PersistConfig) { Write-Host ("[fido] Would set Iso.FidoScriptPath to {0}" -f $targetPath) -ForegroundColor DarkCyan }
        return $targetPath
    }

    try {
        if (-not (Test-Path -Path $DestinationDir)) { New-Item -Path $DestinationDir -ItemType Directory -Force | Out-Null }
        Write-Host ("[fido] Downloading script from {0}" -f $SourceUrl) -ForegroundColor Cyan
        Invoke-WebRequest -Uri $SourceUrl -OutFile $targetPath -UseBasicParsing -ErrorAction Stop
        if ($PersistConfig) {
            $cfg = Get-RiDConfig
            if (-not $cfg['Iso']) { $cfg['Iso'] = @{} }
            $cfg['Iso']['FidoScriptPath'] = $targetPath
            Set-RiDConfig -Config $cfg
            Write-Host ("[fido] Config updated: Iso.FidoScriptPath = {0}" -f $targetPath) -ForegroundColor Cyan
        }
        return $targetPath
    } catch {
        Write-Error "Failed to download Fido script: $_"
        return $null
    }
}
