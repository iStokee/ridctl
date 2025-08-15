function Test-RiDVirtualization {
    <#
    .SYNOPSIS
        Performs virtualization readiness checks for RiD.

    .DESCRIPTION
        Determines whether the current session is running inside a
        virtual machine.  If running on a physical host, queries CPU
        virtualization support, BIOS enablement and optional Windows
        features that may interfere with VMware Workstation.  Based on
        the results, prints guidance to the user and returns an exit
        code according to the following scheme:

        * 0 - Ready: virtualization extensions available and enabled, no major conflicts.
        * 1 - Warning: virtualization enabled but conflicting features (e.g. Hyper-V) detected.
        * 2 - Not ready: virtualization unsupported or disabled.

    .PARAMETER Detailed
        Prints verbose details about each check when supplied.
    #>
    [CmdletBinding()] param(
        [switch]$Detailed
    )

    $isVm = Get-RiDHostGuestInfo
    if ($isVm) {
        Write-Host 'This command is running inside a virtual machine. Virtualization readiness checks apply only to the host.' -ForegroundColor Yellow
        return 0
    }

    $virt = Get-RiDVirtSupport
    $exitCode = 0
    
    if ($null -eq $virt.VTSupported -or -not $virt.VTSupported) {
        Write-Host 'Your processor does not appear to support hardware virtualization (VT-x or AMD-V).' -ForegroundColor Red
        $exitCode = 2
    } elseif (-not $virt.VTEnabled) {
        Write-Host 'Hardware virtualization support is present but disabled in BIOS/UEFI.' -ForegroundColor Red
        # Suggest the user search for how to enable virtualization in the BIOS
        try {
            $baseBoard = Get-CimInstance -ClassName Win32_BaseBoard -ErrorAction Stop
            $mfg   = ($baseBoard.Manufacturer).Trim()
            $model = ($baseBoard.Product).Trim()
            $query = "$mfg $model enable virtualization in BIOS"
            Write-Host "Opening browser to help you enable virtualization..." -ForegroundColor Cyan
            Open-RiDBrowser -Url ("https://www.bing.com/search?q=" + [uri]::EscapeDataString($query))
        } catch {
            Write-Verbose "Failed to determine baseboard information: $_"
        }
        $exitCode = 2
    } else {
        Write-Host 'Hardware virtualization appears to be enabled.' -ForegroundColor Green
    }

    # Check optional Windows features that may interfere
    # Treat WSL presence as informational rather than a direct conflict.
    $conflicts = @()
    $infos = @()
    if ($virt.HyperVPresent) { $conflicts += 'Hyper-V' }
    if ($virt.VirtualMachinePlatformPresent) { $conflicts += 'Virtual Machine Platform' }
    if ($virt.WindowsHypervisorPlatformPresent) { $conflicts += 'Windows Hypervisor Platform' }
    if ($virt.WindowsSandboxPresent) { $conflicts += 'Windows Sandbox' }
    if ($virt.DeviceGuardVBSRunning) { $conflicts += 'Device Guard / VBS (running)' }
    if ($virt.HypervisorLaunchTypeActive) { $conflicts += 'Hyper-V hypervisor (active)'}
    if ($virt.MemoryIntegrityEnabled) { $conflicts += 'Core Isolation/Memory Integrity (HVCI)' }
    if ($virt.WslPresent) { $infos += 'Windows Subsystem for Linux (WSL) feature enabled' }
    if ($conflicts.Count -gt 0) {
        Write-Host ('The following Windows features are enabled and may interfere with VMware Workstation: ' + ($conflicts -join ', ')) -ForegroundColor Yellow
        # One-line next steps summary
        $steps = @()
        if ($virt.HyperVPresent) { $steps += 'Disable "Hyper-V" feature' }
        if ($virt.VirtualMachinePlatformPresent) { $steps += 'Disable "Virtual Machine Platform"' }
        if ($virt.WindowsHypervisorPlatformPresent) { $steps += 'Disable "Windows Hypervisor Platform"' }
        if ($virt.WindowsSandboxPresent) { $steps += 'Disable "Windows Sandbox"' }
        if ($virt.HypervisorLaunchTypeActive) { $steps += 'Run: bcdedit /set hypervisorlaunchtype off' }
        if ($virt.MemoryIntegrityEnabled) { $steps += 'Turn off Core Isolation > Memory Integrity' }
        if ($virt.DeviceGuardVBSRunning) { $steps += 'Disable Device Guard / VBS' }
        if ($steps.Count -gt 0) {
            Write-Host ('Next steps: ' + ($steps -join '; ') + '; reboot required for changes to take effect.') -ForegroundColor Yellow
        } else {
            Write-Host 'Consider disabling these features if you encounter issues running virtual machines.' -ForegroundColor Yellow
        }
        if ($exitCode -eq 0) { $exitCode = 1 }
    } else {
        if ($virt.VTEnabled) {
            Write-Host 'No conflicting Windows virtualization features detected.' -ForegroundColor Green
        }
    }

    if ($Detailed) {
        Write-Host "`nDetailed results:" -ForegroundColor Cyan

        # Overall summary
        $overall = 'Unknown'
        if ($virt.VTSupported -ne $true) { $overall = 'Not Ready' }
        elseif ($virt.VTEnabled -ne $true) { $overall = 'Not Ready' }
        elseif ($conflicts.Count -gt 0) { $overall = 'Conflicted' }
        else { $overall = 'Ready' }
        $overallColor = switch ($overall) { 'Ready' {'Green'} 'Conflicted' {'Yellow'} 'Not Ready' {'Red'} default {'Yellow'} }
        Write-Host ("  Overall: {0}" -f $overall) -ForegroundColor $overallColor

        # Reasons when not ready
        if ($overall -eq 'Not Ready') {
            if ($virt.VTSupported -ne $true) { Write-Host '    Reason: CPU does not support VT-x/AMD-V' -ForegroundColor Red }
            elseif ($virt.VTEnabled -ne $true) { Write-Host '    Reason: Virtualization disabled in BIOS/UEFI' -ForegroundColor Red }
        }

        # Conflicts section
        if ($conflicts.Count -gt 0) {
            Write-Host ('  Conflicts: ' + ($conflicts -join ', ')) -ForegroundColor Yellow
        } else {
            Write-Host '  Conflicts: None' -ForegroundColor Green
        }

        # Informational
        if ($infos.Count -gt 0) {
            Write-Host ('  Info: ' + ($infos -join ', ')) -ForegroundColor White
        }

        # Raw values for transparency
        Write-Host ("  VTSupported: {0}" -f $virt.VTSupported)
        Write-Host ("  VTEnabled:   {0}" -f $virt.VTEnabled)
        Write-Host ("  HyperV:      {0}" -f $virt.HyperVPresent)
        Write-Host ("  VMP:         {0}" -f $virt.VirtualMachinePlatformPresent)
        Write-Host ("  WHP:         {0}" -f $virt.WindowsHypervisorPlatformPresent)
        Write-Host ("  WSL:         {0}" -f $virt.WslPresent)
        Write-Host ("  HypervisorLaunchActive: {0}" -f $virt.HypervisorLaunchTypeActive)
        Write-Host ("  HypervisorPresentNow:   {0}" -f $virt.HypervisorPresent)
        Write-Host ("  WindowsSandbox:         {0}" -f $virt.WindowsSandboxPresent)
        Write-Host ("  DeviceGuardVBSConfigured: {0}" -f $virt.DeviceGuardVBSConfigured)
        Write-Host ("  DeviceGuardVBSRunning:    {0}" -f $virt.DeviceGuardVBSRunning)
        Write-Host ("  HVCI (Memory Integrity): {0}" -f $virt.MemoryIntegrityEnabled)

        # Hint about reboots affecting feature activation
        if ($conflicts.Count -gt 0 -or $infos.Count -gt 0) {
            Write-Host '  Note: Enabling/disabling virtualization features often requires a reboot to take effect.' -ForegroundColor DarkGray
        }
    }

    return $exitCode
}
