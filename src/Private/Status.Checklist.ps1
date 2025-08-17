function Get-RiDChecklistStatus {
    [CmdletBinding()] param()
    $agg = Get-RiDAggregateStatus
    $cfg = Get-RiDConfig

    $isGuest = $agg.IsVM
    $res = [ordered]@{}

    if ($isGuest) {
        # Guest checks
        $prep = Ensure-RiDGuestPrereqs
        $res['Admin']            = $prep.Admin
        $res['winget']           = $prep.WingetAvailable
        $res['choco']            = $prep.ChocoAvailable
        $res['BITS available']   = $prep.BitsAvailable
        $res['TLS 1.2+ enabled'] = $prep.TlsSet

        $res['7-Zip installed']  = Test-RiD7ZipPresent
        $res['Java JRE present'] = Test-RiDJavaPresent
        $res['RiD folder exists'] = Test-RiDRiDInstalled
        $shareName = if ($cfg['Share'] -and $cfg['Share']['Name']) { [string]$cfg['Share']['Name'] } else { 'rid' }
        $res[("Shared folder (\\\\vmware-host\\Shared Folders\\{0})" -f $shareName)] = [bool]$agg.SharedFolderOk
    } else {
        # Host checks
        $res['Virtualization Ready'] = $agg.VirtualizationOk
        $res['VMware Installed']     = $agg.VmwareInstalled
        $res['VMware Version']       = $agg.VmwareVersion
        try { $wk = Get-RiDWorkstationInfo } catch {}
        $tools = Get-RiDVmTools
        $vmrunPath = ''
        $vmcliPath = ''
        try { if ($tools -and $tools.VmrunPath) { $vmrunPath = [string]$tools.VmrunPath } } catch { }
        try { if ($tools -and $tools.VmCliPath)  { $vmcliPath = [string]$tools.VmCliPath } } catch { }
        $res['vmrun path'] = $vmrunPath
        $res['vmcli path'] = $vmcliPath

        $shareHost = if ($cfg['Share'] -and $cfg['Share']['HostPath']) { [string]$cfg['Share']['HostPath'] } else { '' }
        $res['Share host path exists'] = if ($shareHost) { Test-Path -LiteralPath $shareHost } else { $false }
        $tplVmx = if ($cfg['Templates']) { [string]$cfg['Templates']['DefaultVmx'] } else { '' }
        $tplSnap= if ($cfg['Templates']) { [string]$cfg['Templates']['DefaultSnapshot'] } else { '' }
        $res['Template VMX set']     = [bool]$tplVmx
        $res['Template Snapshot set']= [bool]$tplSnap
        $res['Template VMX exists']  = if ($tplVmx) { Test-Path -LiteralPath $tplVmx } else { $false }
        $res['Download dir exists']  = if ($cfg['Iso'] -and $cfg['Iso']['DefaultDownloadDir']) { Test-Path -LiteralPath ([string]$cfg['Iso']['DefaultDownloadDir']) } else { $false }
        $cfgPath = ''
        try { $cfgPath = [string]$cfg['Iso']['FidoScriptPath'] } catch { $cfgPath = '' }
        $detected = ''
        try { $detected = [string](Get-RiDFidoScriptPath) } catch { $detected = '' }
        $pathToShow = if ($cfgPath) { $cfgPath } elseif ($detected) { $detected } else { '' }
        $available = $false
        try {
            if ($pathToShow -and (Test-Path -LiteralPath $pathToShow)) { $available = $true }
            elseif ($detected -and (Test-Path -LiteralPath $detected)) { $available = $true }
            elseif (Test-Path -LiteralPath 'C:\\ISO\\fido\\Fido.ps1') { $available = $true }
        } catch { }
        $res['Fido script path']      = $pathToShow
        $res['Fido script available'] = $available

        $vms = @(Get-RiDVM)
        $res['Registered VMs'] = $vms.Count
    }

    return [pscustomobject]$res
}

function Write-RiDChecklist {
    [CmdletBinding()] param([Parameter(Mandatory=$true)][psobject]$Checklist)
    function _S([object]$v) {
        if ($null -eq $v) { return '' }
        if ($v -is [System.Collections.IDictionary] -or ($v -is [System.Collections.IEnumerable] -and -not ($v -is [string]))) {
            return (ConvertTo-Json -InputObject $v -Depth 5 -Compress)
        }
        return [string]$v
    }
    foreach ($p in $Checklist.PSObject.Properties) {
        $name = $p.Name
        $val  = $p.Value
        $txt  = _S $val
        $color = 'White'
        if ($val -is [bool]) { $color = if ($val) { 'Green' } else { 'Yellow' }; $txt = if ($val) { 'OK' } else { 'Not set' } }
        elseif ([string]::IsNullOrWhiteSpace($txt)) { $txt = 'Not set'; $color = 'Yellow' }
        # Avoid type-name leakage if something upstream passed a non-scalar
        if ($txt -match '^System\.Collections\.(Hashtable|Generic\.)' -or $txt -match '^System\.Management\.Automation\.PSCustomObject') {
            $txt = 'Not set'
            if ($color -eq 'White') { $color = 'Yellow' }
        }
        Write-Host ("- {0}: {1}" -f $name, $txt) -ForegroundColor $color
    }
}
