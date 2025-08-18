function Get-RiDVM {
    <#
    .SYNOPSIS
        Lists registered VMs or returns a specific VM by name.

    .PARAMETER Name
        Optional name to filter by. If provided, returns at most one entry (the first matching name case-insensitively).
    #>
    [CmdletBinding()] param(
        [Parameter()] [string]$Name
    )
    $list = Get-RiDVmRegistry
    $objs = @()
    foreach ($v in $list) {
        $exists = $false
        if ($v.VmxPath) { $exists = Test-Path -LiteralPath $v.VmxPath }
        $prov = ''
        try { if ($v.PSObject.Properties.Name -contains 'Provider') { $prov = [string]$v.Provider } } catch { }
        $objs += [pscustomobject]@{
            Name     = $v.Name
            VmxPath  = $v.VmxPath
            Provider = $prov
            Exists   = [bool]$exists
            ShareName= $v.ShareName
            HostPath = $v.HostPath
            Notes    = $v.Notes
        }
    }
    if ($Name) {
        return ($objs | Where-Object { $_.Name -and ($_.Name -as [string]).ToLowerInvariant() -eq $Name.ToLowerInvariant() } | Select-Object -First 1)
    }
    return $objs
}
