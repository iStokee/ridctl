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
        WslPresent                    = $null
        HypervisorLaunchTypeActive    = $null
        MemoryIntegrityEnabled        = $null
        HypervisorPresent             = $null
        WindowsSandboxPresent         = $null
        DeviceGuardVBSConfigured      = $null
        DeviceGuardVBSRunning         = $null
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
            $wsl = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -ErrorAction SilentlyContinue
            if ($null -ne $wsl) {
                $result.WslPresent = ($wsl.State -eq 'Enabled')
            }
            $wsb = Get-WindowsOptionalFeature -Online -FeatureName Containers-DisposableClientVM -ErrorAction SilentlyContinue
            if ($null -ne $wsb) {
                $result.WindowsSandboxPresent = ($wsb.State -eq 'Enabled')
            }
        }
    } catch {
        Write-Verbose "Failed to query optional features: $_"
    }

    # bcdedit hypervisorlaunchtype (if 'Auto' or 'On', Hyper-V hypervisor is active)
    try {
        if (Get-Command -Name bcdedit.exe -ErrorAction SilentlyContinue) {
            $out = bcdedit /enum | Out-String
            if ($out -match 'hypervisorlaunchtype\s+([A-Za-z]+)') {
                $val = $Matches[1]
                $result.HypervisorLaunchTypeActive = ($val -notmatch 'Off')
            }
        }
    } catch { Write-Verbose "Failed to query bcdedit: $_" }

    # Memory integrity (HVCI)
    try {
        $regPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity'
        $enabled = Get-ItemProperty -Path $regPath -Name Enabled -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Enabled -ErrorAction SilentlyContinue
        if ($null -ne $enabled) { $result.MemoryIntegrityEnabled = ($enabled -eq 1) }
    } catch { Write-Verbose "Failed to query HVCI: $_" }

    # Device Guard / VBS status
    try {
        $dg = Get-CimInstance -Namespace 'root/Microsoft/Windows/DeviceGuard' -ClassName Win32_DeviceGuard -ErrorAction SilentlyContinue
        if ($dg) {
            $cfg = @($dg.SecurityServicesConfigured)
            $run = @($dg.SecurityServicesRunning)
            $vbsStatus = $dg.VirtualizationBasedSecurityStatus
            $result.DeviceGuardVBSConfigured = ($vbsStatus -gt 0 -or $cfg.Count -gt 0)
            $result.DeviceGuardVBSRunning    = ($run.Count -gt 0)
            # Prefer running list to set MemoryIntegrityEnabled if detectable
            if ($run -contains 2) { $result.MemoryIntegrityEnabled = $true }
        }
    } catch { Write-Verbose "Failed to query Device Guard: $_" }

    # Hypervisor present (running now)
    try {
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
        if ($cs -and ($cs.PSObject.Properties.Name -contains 'HypervisorPresent')) {
            $result.HypervisorPresent = [bool]$cs.HypervisorPresent
        }
    } catch { Write-Verbose "Failed to query computer system hypervisor presence: $_" }
    return $result
}
