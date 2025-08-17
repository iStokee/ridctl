<#
    Loads and saves RiD configuration files from the system and user
    locations.  Configuration is stored in JSON format in
    %ProgramData%\ridctl\config.json and overridden by
    %UserProfile%\.ridctl\config.json.
#>

function Get-RiDConfig {
    [CmdletBinding()] param()

    $paths = _Get-RiDConfigPaths
    $merged = @{}

    # Merge order: System -> User -> Local (Local overrides others)
    foreach ($p in @($paths.System, $paths.User, $paths.Local)) {
        if ($p -and (Test-Path -Path $p)) {
            try {
                $raw = Get-Content -Path $p -Raw -ErrorAction Stop
                if ($raw -and $raw.Trim()) {
                    $obj = ConvertFrom-Json -InputObject $raw -ErrorAction Stop
                    $ht  = _ConvertToHashtable $obj
                    foreach ($k in $ht.Keys) { $merged[$k] = $ht[$k] }
                }
            } catch {
                Write-Verbose "Failed to parse configuration file '$p': $_"
            }
        }
    }
    return $merged
}

function Set-RiDConfig {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config,
        [switch]$PassThru
    )

    $paths = _Get-RiDConfigPaths

    # Serialize once
    $json = $Config | ConvertTo-Json -Depth 10

    # 1) Update any config files that already exist (Local/User/System)
    $updated = @()
    foreach ($f in @($paths.Local, $paths.User, $paths.System)) {
        if ($f -and (Test-Path -LiteralPath $f)) {
            if ($PSCmdlet.ShouldProcess($f, 'Update config')) {
                try {
                    $dir = Split-Path -Path $f -Parent
                    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
                    $json | Out-File -LiteralPath $f -Encoding UTF8 -Force
                    $updated += $f
                } catch { Write-Error $_ }
            }
        }
    }

    # 2) If none existed, write to preferred target (repo-local if developing, else user)
    if ($updated.Count -eq 0) {
        $preferLocal = $false
        try {
            # Prefer local if we're inside the repo (Show-RiDMenu already relies on this heuristic) 
            $repoRoot = (Get-Location).Path
            $maybeSrc = Join-Path $repoRoot 'src'
            if (Test-Path -LiteralPath $maybeSrc) { $preferLocal = $true }
            if ($env:RIDCTL_USE_LOCAL_CONFIG -and ($env:RIDCTL_USE_LOCAL_CONFIG -in @('1','true','yes','y'))) { $preferLocal = $true }
        } catch {}

        $target = if ($preferLocal -and $paths.Local) { $paths.Local } elseif ($paths.User) { $paths.User } else { $paths.System }
        if ($target -and $PSCmdlet.ShouldProcess($target, 'Create config')) {
            try {
                $dir = Split-Path -Path $target -Parent
                if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
                $json | Out-File -LiteralPath $target -Encoding UTF8 -Force
                $updated += $target
            } catch { Write-Error $_ }
        }
    }

    if ($PassThru) { return $Config }
}


function Get-RiDDefaultConfig {
    [CmdletBinding()] param()
    $downloads = $null
    try { $downloads = Join-Path -Path $env:USERPROFILE -ChildPath 'Downloads' } catch { }
    if (-not $downloads -or -not (Test-Path -Path $downloads)) { $downloads = $env:USERPROFILE }
    $def = @{}
    $def['Vms'] = @()
    $def['Iso'] = @{
        'DefaultDownloadDir' = $downloads
        'FidoScriptPath'     = ''
        'Release'            = '23H2'
        'Edition'            = 'Pro'
        'Arch'               = 'x64'
    }
    $def['Templates'] = @{
        'DefaultVmx'      = ''
        'DefaultSnapshot' = ''
    }
    $def['Share'] = @{
        'Name'     = 'rid'
        'HostPath' = 'C:\\RiDShare'
    }
    $def['Sync'] = @{
        'DefaultLocalPath' = ''
        'Excludes'         = @()
    }
    $def['Vmware'] = @{
        'vmrunPath' = ''
    }
    # Defaults for creating new VMs via the menu
    $def['VmDefaults'] = @{
        'DestinationBase' = 'C:\\VMs'
        'CpuCount'        = '2'
        'MemoryMB'        = '4096'
        'DiskGB'          = '60'
        'Method'          = 'auto'
    }
    return $def
}

function Initialize-RiDConfig {
    <#
        Ensures a configuration file exists. If none exists, creates one
        with sensible defaults. If one exists, merges in any missing
        default keys (non-destructively) and saves only if changes were
        made.
    #>
    [CmdletBinding()] param()
    $paths = _Get-RiDConfigPaths

    # Reuse Set-RiDConfig preference for local vs user when saving
    $preferLocal = $false
    if ($env:RIDCTL_USE_LOCAL_CONFIG) {
        $preferLocal = [bool]($env:RIDCTL_USE_LOCAL_CONFIG -match '^(1|true|yes)$')
    } else {
        try {
            if ($paths.Local) {
                $repoDir = Split-Path -Path $paths.Local -Parent
                if ($repoDir -and (Test-Path (Join-Path $repoDir 'src'))) {
                    $preferLocal = $true
                }
            }
        } catch { }
    }

    $target = $null
    if ($preferLocal -and $paths.Local) {
        $target = $paths.Local
    } elseif ($paths.User) {
        $target = $paths.User
    } else {
        $target = $paths.System
    }

    $existing = $null
    $script:RiDConfigCreatedNew = $false
    if ($target -and (Test-Path -Path $target)) {
        try {
            $raw = Get-Content -Path $target -Raw -ErrorAction Stop
            if ($raw -and $raw.Trim()) {
                $existing = _ConvertToHashtable (ConvertFrom-Json -InputObject $raw)
            }
        } catch { }
    }
    
    # Determine if this is a brand new configuration session.
    # Consider ANY existing config file (Local/User/System) as existing,
    # not just the preferred target. This prevents false first-run prompts
    # when a user config exists but the local file does not.
    $anyExisting = $false
    foreach ($p in @($paths.Local, $paths.User, $paths.System)) {
        if ($p -and (Test-Path -LiteralPath $p)) { $anyExisting = $true; break }
    }
    if (-not $anyExisting) { $script:RiDConfigCreatedNew = $true }

    $defaults = Get-RiDDefaultConfig
    $merged = @{}
    if ($existing) { foreach ($k in $existing.Keys) { $merged[$k] = $existing[$k] } }
    foreach ($key in $defaults.Keys) {
        if (-not $merged.ContainsKey($key) -or $null -eq $merged[$key]) {
            $merged[$key] = $defaults[$key]
        } elseif ($merged[$key] -is [System.Collections.IDictionary]) {
            # Merge nested dictionaries non-destructively
            $dst = @{} + $merged[$key]
            foreach ($nk in $defaults[$key].Keys) {
                if (-not $dst.ContainsKey($nk)) { $dst[$nk] = $defaults[$key][$nk] }
            }
            $merged[$key] = $dst
        }
    }

    # Normalize types (coerce leaf values to strings for known keys)
    $merged = _Normalize-RiDConfig -Config $merged -Defaults $defaults

    # Save only if file missing or content changed
    $shouldSave = $false
    if (-not (Test-Path -Path $target)) { $shouldSave = $true }
    else {
        try {
            $jsonOld = (Get-Content -Path $target -Raw -ErrorAction Stop)
            $jsonNew = (ConvertTo-Json -InputObject $merged -Depth 10)
            if ($jsonOld -ne $jsonNew) { $shouldSave = $true }
        } catch { $shouldSave = $true }
    }
    if ($shouldSave) { Set-RiDConfig -Config $merged }
    return $merged
}

function _Get-RiDConfigPaths {
    $programData = $env:ProgramData
    $userProfile = $env:USERPROFILE
    $systemFile = $null
    $userFile   = $null
    $localFile  = $null

    if ($programData) { $systemFile = Join-Path -Path $programData -ChildPath 'ridctl\config.json' }
    if ($userProfile) { $userFile   = Join-Path -Path $userProfile -ChildPath '.ridctl\config.json' }

    # Determine repo root using module base (robust when imported as a module)
    try {
        $moduleBase = $ExecutionContext.SessionState.Module.ModuleBase
        if ($moduleBase -and (Test-Path -Path (Join-Path -Path $moduleBase -ChildPath 'ridctl.psd1'))) {
            # When ModuleBase points to 'src'
            $repoRoot = Split-Path -Path $moduleBase -Parent
            $localFile = Join-Path -Path $repoRoot -ChildPath 'config.json'
        } else {
            # Fallback: walk up from this script root until we find repo/src with manifest
            $probe = $PSScriptRoot
            for ($i = 0; $i -lt 5; $i++) {
                if (-not $probe) { break }
                $srcPath = Join-Path -Path $probe -ChildPath 'src'
                $psd1    = Join-Path -Path $srcPath -ChildPath 'ridctl.psd1'
                if (Test-Path -Path $psd1) { $localFile = Join-Path -Path $probe -ChildPath 'config.json'; break }
                $probe = Split-Path -Path $probe -Parent
            }
        }
    } catch { }

    # Allow explicit override via RIDCTL_CONFIG
    if ($env:RIDCTL_CONFIG) { $localFile = $env:RIDCTL_CONFIG }

    return [pscustomobject]@{ System = $systemFile; User = $userFile; Local = $localFile }
}

function _Normalize-RiDConfig {
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)] [hashtable]$Config,
        [Parameter(Mandatory=$true)] [hashtable]$Defaults
    )

    function Coerce([object]$val) {
        if ($null -eq $val) { return '' }
        if ($val -is [string]) { return $val }
        if ($val -is [System.Collections.IDictionary] -or ($val -is [System.Collections.IEnumerable] -and -not ($val -is [string]))) {
            return ''  # bad type for a leaf; reset to empty string
        }
        return [string]$val
    }

    $cfg = $Config.Clone()

    foreach ($sec in @('Iso','Templates','Share','Vmware','Sync','VmDefaults')) {
        if (-not $cfg.ContainsKey($sec) -or -not ($cfg[$sec] -is [System.Collections.IDictionary])) { $cfg[$sec] = @{} }
    }

    $cfg['Iso']['DefaultDownloadDir'] = Coerce $cfg['Iso']['DefaultDownloadDir']
    $cfg['Iso']['FidoScriptPath']     = Coerce $cfg['Iso']['FidoScriptPath']
    $cfg['Iso']['Release']            = Coerce $cfg['Iso']['Release']
    $cfg['Iso']['Edition']            = Coerce $cfg['Iso']['Edition']
    $cfg['Iso']['Arch']               = Coerce $cfg['Iso']['Arch']

    $cfg['Templates']['DefaultVmx']      = Coerce $cfg['Templates']['DefaultVmx']
    $cfg['Templates']['DefaultSnapshot'] = Coerce $cfg['Templates']['DefaultSnapshot']

    $cfg['Share']['Name']     = Coerce $cfg['Share']['Name']
    $cfg['Share']['HostPath'] = Coerce $cfg['Share']['HostPath']

    $cfg['Vmware']['vmrunPath'] = Coerce $cfg['Vmware']['vmrunPath']

    # Sync section
    $cfg['Sync']['DefaultLocalPath'] = Coerce $cfg['Sync']['DefaultLocalPath']
    $ex = $cfg['Sync']['Excludes']
    if ($null -eq $ex) { $cfg['Sync']['Excludes'] = @() }
    elseif ($ex -is [System.Collections.IEnumerable] -and -not ($ex -is [string])) {
        $list = @()
        foreach ($i in $ex) { $list += (Coerce $i) }
        $cfg['Sync']['Excludes'] = $list
    } else {
        $cfg['Sync']['Excludes'] = @((Coerce $ex))
    }

    # Always make Vms an array
    $vms = $cfg['Vms']
    if ($vms -is [System.Collections.IEnumerable] -and -not ($vms -is [string])) {
        $cfg['Vms'] = @($vms)
    } elseif ($null -eq $vms) {
        $cfg['Vms'] = @()
    } else {
        $cfg['Vms'] = @($vms)
    }

    # VmDefaults coercion
    $cfg['VmDefaults']['DestinationBase'] = Coerce $cfg['VmDefaults']['DestinationBase']
    $cfg['VmDefaults']['CpuCount']        = Coerce $cfg['VmDefaults']['CpuCount']
    $cfg['VmDefaults']['MemoryMB']        = Coerce $cfg['VmDefaults']['MemoryMB']
    $cfg['VmDefaults']['DiskGB']          = Coerce $cfg['VmDefaults']['DiskGB']
    $cfg['VmDefaults']['Method']          = Coerce $cfg['VmDefaults']['Method']

    return $cfg
}


function _ConvertToHashtable($obj) {
    if ($null -eq $obj) { return @{} }
    if ($obj -is [hashtable]) { return $obj }
    if ($obj -is [System.Collections.IDictionary]) { return @{} + $obj }
    if ($obj -is [System.Collections.IEnumerable] -and -not ($obj -is [string])) {
        $list = @()
        foreach ($item in $obj) { $list += _ConvertToHashtable $item }
        return $list
    }
    # PSCustomObject -> Hashtable
    $ht = @{}
    $props = $obj | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
    foreach ($p in $props) { $ht[$p] = _ConvertToHashtable ($obj.$p) }
    return $ht
}
