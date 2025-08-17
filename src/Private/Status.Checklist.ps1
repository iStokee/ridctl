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
        $res['vmrun path']          = if ($tools.VmrunPath) { $tools.VmrunPath } else { '' }
        $res['vmcli path']          = if ($tools.VmCliPath) { $tools.VmCliPath } else { '' }

        $shareHost = if ($cfg['Share'] -and $cfg['Share']['HostPath']) { [string]$cfg['Share']['HostPath'] } else { '' }
        $res['Share host path exists'] = if ($shareHost) { Test-Path -LiteralPath $shareHost } else { $false }
        $tplVmx = if ($cfg['Templates']) { [string]$cfg['Templates']['DefaultVmx'] } else { '' }
        $tplSnap= if ($cfg['Templates']) { [string]$cfg['Templates']['DefaultSnapshot'] } else { '' }
        $res['Template VMX set']     = [bool]$tplVmx
        $res['Template Snapshot set']= [bool]$tplSnap
        $res['Template VMX exists']  = if ($tplVmx) { Test-Path -LiteralPath $tplVmx } else { $false }
        $res['Download dir exists']  = if ($cfg['Iso'] -and $cfg['Iso']['DefaultDownloadDir']) { Test-Path -LiteralPath ([string]$cfg['Iso']['DefaultDownloadDir']) } else { $false }
        $cfgPath = ''
        try {
            $cfgPath = [string]$cfg['Iso']['FidoScriptPath']
        } catch { $cfgPath = '' }
        $detected = Get-RiDFidoScriptPath
        $pathToShow = if ($cfgPath) { $cfgPath } elseif ($detected) { [string]$detected } else { '' }
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
    foreach ($p in $Checklist.PSObject.Properties) {
        $name = $p.Name
        $val  = $p.Value
        $txt  = [string]$val
        $color = 'White'
        if ($val -is [bool]) { $color = if ($val) { 'Green' } else { 'Yellow' }; $txt = if ($val) { 'OK' } else { 'Not set' } }
        elseif ([string]::IsNullOrWhiteSpace($txt)) { $txt = 'Not set'; $color = 'Yellow' }
        Write-Host ("- {0}: {1}" -f $name, $txt) -ForegroundColor $color
    }
}
