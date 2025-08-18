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

