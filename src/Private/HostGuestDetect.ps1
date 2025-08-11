function Get-RiDHostGuestInfo {
    <#
    .SYNOPSIS
        Determines whether the current session is running on a physical
        host or inside a virtual machine.

    .DESCRIPTION
        Uses Win32_ComputerSystem to inspect the computer manufacturer
        and model.  If the manufacturer or model contains common
        hypervisor vendor names (e.g. VMware, VirtualBox, KVM,
        Hyper-V, Xen) the session is considered to be running inside
        a VM.  Otherwise it is assumed to be a physical host.

    .OUTPUTS
        [bool] True if running inside a VM, False if on a physical host.
    #>
    [CmdletBinding()] param()

    try {
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        $manufacturer = ($cs.Manufacturer).ToString()
        $model        = ($cs.Model).ToString()
        $vmVendors = @('VMware', 'VirtualBox', 'KVM', 'Microsoft Corporation', 'Xen', 'QEMU', 'Parallels')
        foreach ($vendor in $vmVendors) {
            if ($manufacturer -like "*$vendor*" -or $model -like "*$vendor*") {
                return $true
            }
        }
    } catch {
        # If WMI fails, conservatively assume we are on a host to avoid
        # suppressing host-only operations.
        Write-Verbose "Failed to query computer system: $_"
    }
    return $false
}