function New-RiDHvVM {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
      [Parameter(Mandatory)][string]$Name,
      [Parameter()][int]$MemoryGB = 4,
      [Parameter()][int]$CpuCount = 2,
      [Parameter()][ValidateSet(1,2)][int]$Generation = 2,
      [Parameter()][string]$VhdPath,
      [Parameter()][int]$DiskGB = 64,
      [Parameter()][string]$IsoPath,
      [Parameter()][string]$SwitchName,
      [Parameter()][string]$Path
    )
    $tools = Get-RiDHvTools
    if (-not $tools.ModulePresent) { throw 'Hyper-V module not available.' }
    if (-not $SwitchName) {
        try { $cfg = Get-RiDConfig; if ($cfg['HyperV'] -and $cfg['HyperV']['SwitchName']) { $SwitchName = [string]$cfg['HyperV']['SwitchName'] } } catch { }
        if (-not $SwitchName) { $SwitchName = 'Default Switch' }
    }
    if ($SwitchName) {
        $sw = Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue
        if (-not $sw) { throw "Hyper-V switch '$SwitchName' not found." }
    }
    $target = $Name
    if ($PSCmdlet.ShouldProcess($target, 'Create Hyper-V VM')) {
        if ($VhdPath -and $DiskGB -gt 0 -and -not (Test-Path -LiteralPath $VhdPath)) {
            New-VHD -Path $VhdPath -SizeBytes ($DiskGB * 1GB) -Dynamic | Out-Null
        }
        $vmParams = @{
            Name               = $Name
            MemoryStartupBytes = ($MemoryGB*1GB)
            Generation         = $Generation
            SwitchName         = $SwitchName
        }
        if ($Path) { $vmParams['Path'] = $Path }
        if ($VhdPath) { $vmParams['VHDPath'] = $VhdPath } else { $vmParams['NoVHD'] = $true }
        New-VM @vmParams | Out-Null
        if ($CpuCount) { Set-VMProcessor -VMName $Name -Count $CpuCount | Out-Null }
        if ($IsoPath) { Set-VMDvdDrive -VMName $Name -Path $IsoPath | Out-Null }
    }
}

function Start-RiDHvVM { [CmdletBinding(SupportsShouldProcess=$true)] param([Parameter(Mandatory)][string]$Name)
    if ($PSCmdlet.ShouldProcess($Name, 'Start Hyper-V VM')) { Start-VM -Name $Name | Out-Null }
}
function Stop-RiDHvVM { [CmdletBinding(SupportsShouldProcess=$true)] param([Parameter(Mandatory)][string]$Name,[switch]$Hard)
    $mode = if ($Hard) { 'TurnOff' } else { 'Shutdown' }
    if ($PSCmdlet.ShouldProcess($Name, ("Stop Hyper-V VM ({0})" -f $mode))) {
        if ($Hard) { Stop-VM -Name $Name -TurnOff | Out-Null }
        else       { Stop-VM -Name $Name -Shutdown | Out-Null }
    }
}
function Checkpoint-RiDHvVM { [CmdletBinding(SupportsShouldProcess=$true)] param([Parameter(Mandatory)][string]$Name,[string]$CheckpointName = (Get-Date -Format 'yyyyMMdd-HHmmss'))
    if ($PSCmdlet.ShouldProcess($Name, ("Create Hyper-V checkpoint '{0}'" -f $CheckpointName))) { Checkpoint-VM -Name $Name -SnapshotName $CheckpointName | Out-Null }
}
function Remove-RiDHvVM { [CmdletBinding(SupportsShouldProcess=$true)] param([Parameter(Mandatory)][string]$Name,[switch]$DeleteVhd)
    $disks = @()
    try { $disks = (Get-VMHardDiskDrive -VMName $Name).Path } catch { }
    if ($PSCmdlet.ShouldProcess($Name, 'Remove Hyper-V VM')) {
        Remove-VM -Name $Name -Force
        if ($DeleteVhd) { $disks | Where-Object { $_ } | ForEach-Object { try { Remove-Item -LiteralPath $_ -Force -ErrorAction SilentlyContinue } catch { } } }
    }
}
