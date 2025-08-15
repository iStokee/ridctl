function Reset-RiDConfig {
    <#
    .SYNOPSIS
        Deletes one or more RiD config files and rebuilds from defaults.

    .DESCRIPTION
        Removes the selected config file(s) and reinitializes configuration
        using Initialize-RiDConfig, which creates/merges defaults.

    .PARAMETER Scope
        Which config file(s) to remove: Local, User, System, or All.
    #>
    [CmdletBinding(SupportsShouldProcess=$true)] param(
        [Parameter()] [ValidateSet('Local','User','System','All')] [string]$Scope = 'Local'
    )
    $paths = _Get-RiDConfigPaths
    $targets = @()
    switch ($Scope) {
        'Local'  { if ($paths.Local)  { $targets += $paths.Local } }
        'User'   { if ($paths.User)   { $targets += $paths.User } }
        'System' { if ($paths.System) { $targets += $paths.System } }
        'All'    {
            foreach ($p in @($paths.Local,$paths.User,$paths.System)) { if ($p) { $targets += $p } }
        }
    }
    foreach ($f in $targets) {
        if (Test-Path -Path $f) {
            if ($PSCmdlet.ShouldProcess($f, 'Delete config file')) {
                try { Remove-Item -Path $f -Force -ErrorAction Stop } catch { Write-Error $_ }
            }
        }
    }
    # Rebuild defaults
    try { $cfg = Initialize-RiDConfig; return $cfg } catch { Write-Error $_ }
}

