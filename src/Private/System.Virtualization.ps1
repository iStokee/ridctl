function Get-RiDVirtSupport {
    <#
    .SYNOPSIS
        Retrieves virtualization support information for the current host.

    .DESCRIPTION
        Queries the Win32_Processor class to determine if the CPU
        supports hardware virtualization and whether it is enabled in
        firmware.  Also inspects optional Windows features that can
        interfere with third‑party hypervisors (Hyper‑V, Virtual
        Machine Platform, Windows Hypervisor Platform).  Returns a
        custom object containing the results of these checks.  If run
        inside a guest VM the properties will be `$null`.

    .OUTPUTS
        [pscustomobject] with the following properties:
          - VTSupported:        [bool]  CPU supports virtualization
          - VTEnabled:          [bool]  Virtualization enabled in BIOS/UEFI
          - HyperVPresent:      [bool]  Hyper‑V optional feature installed
          - VirtualMachinePlatformPresent: [bool]  Virtual Machine Platform feature installed
          - WindowsHypervisorPlatformPresent: [bool]  Windows Hypervisor Platform feature installed
    #>
    [CmdletBinding()] param()

    # Default values
    $result = [pscustomobject]@{
        VTSupported                   = $null
        VTEnabled                     = $null
        HyperVPresent                 = $null
        VirtualMachinePlatformPresent = $null
        WindowsHypervisorPlatformPresent = $null
    }

    # Skip checks if running inside a guest
    if (Get-RiDHostGuestInfo) {
        return $result
    }

    try {
        $processors = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop
        # Determine support and enabled state by checking properties on any processor.
        $supports = $false
        $enabled  = $false
        foreach ($proc in $processors) {
            # VirtualizationFirmwareEnabled is true when VT is enabled in BIOS/UEFI
            if ($proc.VirtualizationFirmwareEnabled -ne $null) {
                if ($proc.VirtualizationFirmwareEnabled) { $enabled = $true }
                # Support indicated if either HardwarePrefetcher/Virtualization attributes or simply presence of property
                $supports = $true
            }
            elseif ($proc.SecondLevelAddressTranslationExtensions -ne $null) {
                # If SLAT exists, virtualization support exists
                $supports = $true
            }
        }
        $result.VTSupported = $supports
        $result.VTEnabled   = $enabled
    } catch {
        Write-Verbose "Failed to query processor information: $_"
    }

    # Query optional Windows features that may conflict with VMware
    try {
        # Only call Get-WindowsOptionalFeature if running on Windows and command available
        if (Get-Command -Name Get-WindowsOptionalFeature -ErrorAction SilentlyContinue) {
            $hyperV = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue
            if ($null -ne $hyperV) {
                $result.HyperVPresent = ($hyperV.State -eq 'Enabled')
            }
            $vmp = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -ErrorAction SilentlyContinue
            if ($null -ne $vmp) {
                $result.VirtualMachinePlatformPresent = ($vmp.State -eq 'Enabled')
            }
            $whp = Get-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform -ErrorAction SilentlyContinue
            if ($null -ne $whp) {
                $result.WindowsHypervisorPlatformPresent = ($whp.State -eq 'Enabled')
            }
        }
    } catch {
        Write-Verbose "Failed to query optional features: $_"
    }
    return $result
}