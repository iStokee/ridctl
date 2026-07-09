function Optimize-RiDGuest {
    <#
    .SYNOPSIS
        Debloats a guest VM as the final step of golden-image prep.

    .DESCRIPTION
        Run inside the guest after the Atlas playbook (and any other setup)
        to strip remaining Windows Store apps and clear caches/temp files
        before you shut down and snapshot the VM as a clone template.
        Removes both installed AppX packages (all users) and their
        provisioned copies so cloned VMs and new user profiles stay clean.

        Safe by default: without -Confirm:$true (or with -WhatIf) it only
        prints the plan.

    .PARAMETER KeepApps
        Wildcard patterns of app names to keep (e.g. 'Microsoft.WindowsCamera').

    .PARAMETER SkipAppx
        Skip Store app removal.

    .PARAMETER SkipTweaks
        Skip the registry tweaks (telemetry off, consumer features off,
        Bing search off, Copilot/Recall off, widgets off, Game DVR off,
        fast startup off).

    .PARAMETER SkipCleanup
        Skip cache/temp cleanup.

    .PARAMETER Force
        Allow running on a machine not detected as a VM guest.

    .EXAMPLE
        PS> Optimize-RiDGuest -WhatIf
        Lists the apps that would be removed and cleanup that would run.

    .EXAMPLE
        PS> Optimize-RiDGuest -Confirm:$true
        Applies the debloat, then you shut down and snapshot the template.
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [string[]]$KeepApps = @(),
        [switch]$SkipAppx,
        [switch]$SkipTweaks,
        [switch]$SkipCleanup,
        [switch]$Force
    )

    # Detection can auto-import CIM modules; keep -WhatIf from leaking into
    # that import (it would spam "Set Alias" WhatIf lines).
    $isGuest = $false
    try {
        $oldWhatIf = $WhatIfPreference
        $WhatIfPreference = $false
        $isGuest = [bool](Get-RiDHostGuestInfo)
    } catch { } finally { $WhatIfPreference = $oldWhatIf }
    if (-not $isGuest -and -not $Force) {
        Write-Warning 'This machine does not look like a VM guest. Debloat is meant for the guest image; re-run with -Force to override.'
        return
    }

    $isAdmin = $false
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $isAdmin = ([Security.Principal.WindowsPrincipal]$identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { }
    if (-not $isAdmin) {
        Write-Warning 'Provisioned package removal requires an elevated session. Re-run from an Administrator PowerShell for full effect.'
    }

    $apply = $PSCmdlet.ShouldProcess('this guest', 'Remove leftover Store apps and clean caches')
    $result = Invoke-RiDGuestDebloat -KeepApps $KeepApps -SkipAppx:$SkipAppx -SkipTweaks:$SkipTweaks -SkipCleanup:$SkipCleanup -Apply:$apply

    if ($apply) {
        Write-Host ("Debloat complete: {0} package action(s) applied, {1} failed." -f $result.Removed, $result.Failed) -ForegroundColor Green
        Write-Host 'Next steps for the golden image:' -ForegroundColor Green
        Write-Host '  - Shut down the guest cleanly.' -ForegroundColor DarkGray
        Write-Host '  - On the host, snapshot the VM (e.g. Checkpoint-RiDVM -Name <template> -SnapshotName Clean).' -ForegroundColor DarkGray
        Write-Host '  - Set Templates.DefaultVmx / Templates.DefaultSnapshot in Options so New-RiDVM clones from it.' -ForegroundColor DarkGray
    } else {
        Write-Host ("Dry-run: {0} package action(s) planned. Re-run with -Confirm:`$true to apply." -f $result.Planned) -ForegroundColor Yellow
    }
    return $result
}
