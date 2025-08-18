<#
    Registry helpers for tracking user-registered VMs by friendly name.
    Data persists in user config under key: Vms (array of objects).
#>

function Get-RiDVmRegistry {
    [CmdletBinding()] param()
    try {
        $cfg = Get-RiDConfig
        $raw = $cfg['Vms']
        $items = @()

        if ($raw -is [System.Collections.IEnumerable] -and -not ($raw -is [string])) {
            $items = @($raw)
        } elseif ($raw) {
            $items = @($raw)
        }

        $out = @()
        foreach ($e in $items) {
            if ($null -eq $e) { continue }
            if ($e -is [System.Collections.IDictionary]) { $e = [pscustomobject]$e }

            $out += [pscustomobject]@{
                Name      = [string]$e.Name
                VmxPath   = [string]$e.VmxPath
                ShareName = $e.ShareName
                HostPath  = $e.HostPath
                Notes     = $e.Notes
                Created   = [string]$e.Created
                Provider  = if ($e.PSObject.Properties.Name -contains 'Provider') { [string]$e.Provider } else { '' }
            }
        }
        return $out
    } catch { Write-Error $_ }
}

function Save-RiDVmRegistry {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # Accept scalar OR list; we’ll normalize.
        [Parameter(Mandatory=$true)]
        [object]$List
    )

    try {
        # Coerce to an array
        $entries = @()
        if ($List -is [System.Collections.IEnumerable] -and -not ($List -is [string])) {
            foreach ($i in $List) { $entries += $i }
        } else {
            $entries = @($List)
        }

        # Normalize each item
        $normalized = @()
        foreach ($e in $entries) {
            if ($null -eq $e) { continue }
            if ($e -is [System.Collections.IDictionary]) { $e = [pscustomobject]$e }

            $normalized += [pscustomobject]@{
                Name      = [string]$e.Name
                VmxPath   = [string]$e.VmxPath
                ShareName = $e.ShareName
                HostPath  = $e.HostPath
                Notes     = $e.Notes
                Created   = if ($e.Created) { [string]$e.Created } else { (Get-Date).ToString('s') }
                Provider  = if ($e.PSObject.Properties.Name -contains 'Provider') { [string]$e.Provider } else { '' }
            }
        }

        # Drop empties, de-dupe by Name (keep last)
        $normalized = $normalized | Where-Object { $_.Name -and $_.VmxPath }
        if ($normalized.Count -gt 1) { $normalized = $normalized | Sort-Object Name -Unique }

        $cfg = Get-RiDConfig
        if (-not $cfg['Vms']) { $cfg['Vms'] = @() }
        $cfg['Vms'] = @($normalized)

        Set-RiDConfig -Config $cfg | Out-Null
        return $cfg['Vms']
    } catch {
        Write-Error $_
    }
}


function Find-RiDVmByName {
    [CmdletBinding()] param([Parameter(Mandatory=$true)][string]$Name)
    $list = Get-RiDVmRegistry
    return $list | Where-Object {
        $_.Name -and ($_.Name -as [string]) -and
        ($_.Name -as [string]).ToLowerInvariant() -eq $Name.ToLowerInvariant()
    }
}

function Add-RiDVmRegistryEntry {
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)] [hashtable]$Entry,
        [Parameter()] [switch]$Force
    )
    if (-not $Entry.Name) { throw 'Entry must include Name.' }
    $prov = ''
    try { if ($Entry.Provider) { $prov = [string]$Entry.Provider } } catch { }
    if (-not $Entry.VmxPath -and $prov -ne 'hyperv') { throw 'Entry must include VmxPath.' }

    $existing = Find-RiDVmByName -Name $Entry.Name
    $list = @(Get-RiDVmRegistry)
    if ($existing -and -not $Force) { throw ("A VM named '{0}' is already registered." -f $Entry.Name) }
    if ($existing) { $list = $list | Where-Object { $_.Name.ToLowerInvariant() -ne ($Entry.Name -as [string]).ToLowerInvariant() } }

    $obj = [pscustomobject]@{
        Name      = [string]$Entry.Name
        VmxPath   = [string]$Entry.VmxPath
        ShareName = $Entry.ShareName
        HostPath  = $Entry.HostPath
        Notes     = $Entry.Notes
        Created   = (Get-Date).ToString('s')
        Provider  = $prov
    }
    $list += $obj

    return (Save-RiDVmRegistry -List $list)
}
function Remove-RiDVmRegistryEntry {
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)] [string]$Name
    )
    $list = Get-RiDVmRegistry
    $before = @($list).Count
    $list = $list | Where-Object { -not ($_.Name -and ($_.Name -as [string]).ToLowerInvariant() -eq $Name.ToLowerInvariant()) }
    if (@($list).Count -eq $before) { Write-Verbose ("No registered VM named '{0}' was found." -f $Name) }
    Save-RiDVmRegistry -List $list
}

function Resolve-RiDVmxFromName {
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)] [string]$Name
    )
    $vm = Find-RiDVmByName -Name $Name | Select-Object -First 1
    if (-not $vm) { Write-Error ("Registered VM not found: {0}" -f $Name); return $null }
    # For Hyper-V entries, VMX is not applicable; callers should branch by provider.
    $prov = ''
    try { if ($vm.PSObject.Properties.Name -contains 'Provider') { $prov = [string]$vm.Provider } } catch { }
    if ($prov -eq 'hyperv') { return $null }
    return ($vm.VmxPath -as [string])
}

function Get-RiDProviderForName {
    [CmdletBinding()] param([Parameter(Mandatory=$true)][string]$Name)
    $vm = Find-RiDVmByName -Name $Name | Select-Object -First 1
    if (-not $vm) { return $null }
    try { if ($vm.PSObject.Properties.Name -contains 'Provider') { return [string]$vm.Provider } } catch { }
    return $null
}
