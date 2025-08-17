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
        [Parameter()] [string]$SourceUrl = 'https://raw.githubusercontent.com/pbatard/Fido/master/powershell/fido.ps1',
        [Parameter()] [string]$PinToCommit,
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
    # Prefer canonical file name used by upstream: Fido.ps1
    $targetPath = Join-Path -Path $DestinationDir -ChildPath 'Fido.ps1'

    if (-not $Apply) {
        Write-Host ("[fido] Would download from {0} -> {1}" -f $SourceUrl, $targetPath) -ForegroundColor DarkCyan
        if ($PersistConfig) { Write-Host ("[fido] Would set Iso.FidoScriptPath to {0}" -f $targetPath) -ForegroundColor DarkCyan }
        return $targetPath
    }

    try {
        if ($PinToCommit) {
            $SourceUrl = ('https://raw.githubusercontent.com/pbatard/Fido/{0}/powershell/fido.ps1' -f $PinToCommit)
        }
        if (-not (Test-Path -Path $DestinationDir)) { New-Item -Path $DestinationDir -ItemType Directory -Force | Out-Null }
        Write-Host ("[fido] Downloading script from {0}" -f $SourceUrl) -ForegroundColor Cyan
        $tried = @()
        $urls = @(
            $SourceUrl,
            # Preferred canonical path in upstream
            'https://raw.githubusercontent.com/pbatard/Fido/master/powershell/fido.ps1',
            'https://raw.githubusercontent.com/pbatard/Fido/refs/heads/master/powershell/fido.ps1',
            # Repo root legacy
            'https://raw.githubusercontent.com/pbatard/Fido/master/Fido.ps1',
            'https://raw.githubusercontent.com/pbatard/Fido/refs/heads/master/Fido.ps1',
            # Be resilient if default branch is 'main'
            'https://raw.githubusercontent.com/pbatard/Fido/main/powershell/fido.ps1',
            'https://raw.githubusercontent.com/pbatard/Fido/refs/heads/main/powershell/fido.ps1',
            'https://raw.githubusercontent.com/pbatard/Fido/main/Fido.ps1',
            'https://raw.githubusercontent.com/pbatard/Fido/refs/heads/main/Fido.ps1'
        ) | Select-Object -Unique
        $ok = $false
        foreach ($u in $urls) {
            $tried += $u
            try {
                Invoke-WebRequest -Uri $u -OutFile $targetPath -UseBasicParsing -ErrorAction Stop
                try { Unblock-File -LiteralPath $targetPath -ErrorAction SilentlyContinue } catch { }
                $ok = $true
                break
            } catch { continue }
        }
        if (-not $ok) {
            Write-Error ("Failed to download Fido script from tried URLs: {0}" -f ($tried -join ', '))
            return $null
        }
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
