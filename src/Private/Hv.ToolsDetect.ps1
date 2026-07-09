<#
    PARKED: Hyper-V support is not currently wired into any public cmdlet.
    ridctl operates VMware-only for now; these helpers are kept for
    potential re-evaluation later.
#>
function Get-RiDHvTools {
    [CmdletBinding()] param()
    $module = $null
    try { $module = Get-Module -ListAvailable -Name Hyper-V } catch { }
    $cmds = @(
        'New-VM','Start-VM','Stop-VM','Checkpoint-VM','Set-VM','Set-VMProcessor',
        'Add-VMHardDiskDrive','New-VHD','Set-VMDvdDrive','Get-VMHardDiskDrive','Get-VMIntegrationService','Enable-VMIntegrationService','Copy-VMFile'
    )
    $cmdsOk = $true
    foreach ($c in $cmds) {
        try { if (-not (Get-Command $c -ErrorAction SilentlyContinue)) { $cmdsOk = $false; break } } catch { $cmdsOk = $false; break }
    }
    [pscustomobject]@{
        ModulePresent = [bool]$module
        CmdletsOk     = [bool]$cmdsOk
    }
}

