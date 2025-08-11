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

        * 0 – Ready: virtualization extensions available and enabled, no major conflicts.
        * 1 – Warning: virtualization enabled but conflicting features (e.g. Hyper‑V) detected.
        * 2 – Not ready: virtualization unsupported or disabled.

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
        Write-Host 'Your processor does not appear to support hardware virtualization (VT‑x or AMD‑V).' -ForegroundColor Red
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
    $conflicts = @()
    if ($virt.HyperVPresent) { $conflicts += 'Hyper‑V' }
    if ($virt.VirtualMachinePlatformPresent) { $conflicts += 'Virtual Machine Platform' }
    if ($virt.WindowsHypervisorPlatformPresent) { $conflicts += 'Windows Hypervisor Platform' }
    if ($conflicts.Count -gt 0) {
        Write-Host ('The following Windows features are enabled and may interfere with VMware Workstation: ' + ($conflicts -join ', ')) -ForegroundColor Yellow
        Write-Host 'Consider disabling these features if you encounter issues running virtual machines.' -ForegroundColor Yellow
        if ($exitCode -eq 0) { $exitCode = 1 }
    } else {
        if ($virt.VTEnabled) {
            Write-Host 'No conflicting Windows virtualization features detected.' -ForegroundColor Green
        }
    }

    if ($Detailed) {
        Write-Host "\nDetailed results:" -ForegroundColor Cyan
        Write-Host ("  VTSupported: {0}" -f $virt.VTSupported)
        Write-Host ("  VTEnabled:   {0}" -f $virt.VTEnabled)
        Write-Host ("  HyperV:      {0}" -f $virt.HyperVPresent)
        Write-Host ("  VMP:         {0}" -f $virt.VirtualMachinePlatformPresent)
        Write-Host ("  WHP:         {0}" -f $virt.WindowsHypervisorPlatformPresent)
    }

    return $exitCode
}