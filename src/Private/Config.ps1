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

    foreach ($p in @($paths.System, $paths.User)) {
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
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)] [hashtable]$Config
    )
    $paths = _Get-RiDConfigPaths
    $userFile = $paths.User
    $userDir  = Split-Path -Path $userFile -Parent
    try {
        if (-not (Test-Path -Path $userDir)) { New-Item -Path $userDir -ItemType Directory -Force | Out-Null }
        $json = ConvertTo-Json -InputObject $Config -Depth 10
        Set-Content -Path $userFile -Value $json -Encoding UTF8
        Write-Verbose ("Configuration saved to {0}" -f $userFile)
    } catch {
        Write-Error "Failed to write configuration: $_"
    }
}

function _Get-RiDConfigPaths {
    $programData = $env:ProgramData
    $userProfile = $env:USERPROFILE
    $systemFile = $null
    $userFile   = $null
    if ($programData) { $systemFile = Join-Path -Path $programData -ChildPath 'ridctl\config.json' }
    if ($userProfile) { $userFile   = Join-Path -Path $userProfile -ChildPath '.ridctl\config.json' }
    return [pscustomobject]@{ System = $systemFile; User = $userFile }
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
