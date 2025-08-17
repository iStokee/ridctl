<#
    Wrapper functions around the traditional VMware Workstation vmrun
    tool.  These support cloning from templates, powering on/off VMs,
    taking snapshots and managing shared folders.
#>
function Invoke-RiDVmrun {
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)] [string]$Command,
        [Parameter()] [string[]]$Arguments,
        [Parameter()] [string]$VmrunPath,
        [Parameter()] [switch]$Apply,
        [Parameter()] [switch]$CaptureOutput,
        [Parameter()] [switch]$AlwaysRun
    )
    if (-not $VmrunPath) {
        $tools = Get-RiDVmTools
        $VmrunPath = $tools.VmrunPath
    }
    if (-not $VmrunPath) {
        Write-Warning 'vmrun executable not found.'
        return $null
    }
    $args = @($Command) + ($Arguments | Where-Object { $_ -ne $null -and $_ -ne '' })
    if (-not $Apply -and -not $AlwaysRun) {
        Write-Host ("[vmrun] {0} {1}" -f $VmrunPath, ($args -join ' ')) -ForegroundColor DarkCyan
        return $null
    }
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $VmrunPath
        $psi.Arguments = ($args -join ' ')
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $p = [System.Diagnostics.Process]::Start($psi)
        $stdout = $p.StandardOutput.ReadToEnd()
        $stderr = $p.StandardError.ReadToEnd()
        $p.WaitForExit()
        if ($stdout) { Write-Verbose $stdout }
        if ($CaptureOutput) {
            if ($p.ExitCode -ne 0 -and $stderr) { Write-Verbose $stderr }
            return [pscustomobject]@{ ExitCode = $p.ExitCode; Stdout = $stdout; Stderr = $stderr }
        }
        if ($p.ExitCode -ne 0) { Write-Error ("vmrun exited with code {0}: {1}" -f $p.ExitCode, $stderr) }
        return $p.ExitCode
    } catch {
        Write-Error "Failed to invoke vmrun: $_"
        return $null
    }
}

function Get-RiDVmrunSnapshots {
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)] [string]$VmxPath,
        [Parameter()] [string]$VmrunPath,
        [Parameter()] [switch]$ShowTree
    )
    $args = @('"{0}"' -f $VmxPath)
    if ($ShowTree) { $args += '-showTree' }
    $res = Invoke-RiDVmrun -VmrunPath $VmrunPath -Command 'listSnapshots' -Arguments $args -AlwaysRun -CaptureOutput
    if ($null -eq $res) { return @() }
    if ($res.ExitCode -ne 0) { return @() }
    $lines = @()
    if ($res.Stdout) {
        $lines = $res.Stdout -split "`r?`n"
    }
    # Filter out header/empty lines and trim tree characters
    $snaps = @()
    foreach ($l in $lines) {
        $t = ($l.Trim())
        if (-not $t) { continue }
        if ($t -match 'Total snapshots') { continue }
        $t = $t.TrimStart('|',' ','`t','`u2502','`u251C','`u2514','-')
        if ($t) { $snaps += $t }
    }
    return $snaps
}

function Clone-RiDVmrunTemplate {
    <#
    .SYNOPSIS
        Clones a VM from a template using vmrun.

    .DESCRIPTION
        Placeholder for clone operations using the vmrun command.  In
        the scaffold this simply prints the intended vmrun command.
    #>
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)] [string]$VmrunPath,
        [Parameter(Mandatory=$true)] [string]$TemplateVmx,
        [Parameter(Mandatory=$true)] [string]$SnapshotName,
        [Parameter(Mandatory=$true)] [string]$DestinationVmx,
        [Parameter()] [switch]$Apply
    )
    if (-not (Test-Path -Path $TemplateVmx)) { Write-Error ("Template VMX not found: {0}" -f $TemplateVmx); return $null }
    $destDir = Split-Path -Path $DestinationVmx -Parent
    if (-not (Test-Path -Path $destDir)) {
        if ($Apply) {
            try { New-Item -Path $destDir -ItemType Directory -Force | Out-Null } catch { Write-Error "Failed to create destination directory: $_"; return $null }
        } else {
            Write-Host ('[fs] New-Item -ItemType Directory -Path "{0}" -Force' -f $destDir) -ForegroundColor DarkCyan
        }
    }
    if (Test-Path -Path $DestinationVmx) {
        Write-Error ("Destination VMX already exists: {0}" -f $DestinationVmx)
        return $null
    }

    # Validate snapshot exists (safe to run without Apply)
    $snaps = Get-RiDVmrunSnapshots -VmrunPath $VmrunPath -VmxPath $TemplateVmx -ShowTree
    if ($snaps -and ($snaps -notcontains $SnapshotName)) {
        Write-Error ("Snapshot '{0}' not found in template. Available: {1}" -f $SnapshotName, ($snaps -join ', '))
        return $null
    }

    $args = @('"{0}"' -f $TemplateVmx, '"{0}"' -f $DestinationVmx, 'full', ('-snapshot="{0}"' -f $SnapshotName))
    $rc = Invoke-RiDVmrun -VmrunPath $VmrunPath -Command 'clone' -Arguments $args -Apply:$Apply
    if ($Apply) {
        if ($rc -ne 0) { Write-Error "vmrun clone failed."; return $null }
        if (-not (Test-Path -Path $DestinationVmx)) { Write-Warning 'Clone reported success but destination VMX not found.' }
    }
    return $DestinationVmx
}

function Test-RiDSharedFolderInGuest {
    <#
    .SYNOPSIS
        Verifies a shared folder visibility inside the guest using vmrun.

    .PARAMETER VmrunPath
        Path to vmrun.exe.

    .PARAMETER VmxPath
        Path to the target VM's .vmx file.

    .PARAMETER ShareName
        Name of the shared folder to verify.

    .PARAMETER GuestUser
        Username in the guest OS.

    .PARAMETER GuestPassword
        Password for the guest user.
    #>
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)] [string]$VmrunPath,
        [Parameter(Mandatory=$true)] [string]$VmxPath,
        [Parameter(Mandatory=$true)] [string]$ShareName,
        [Parameter(Mandatory=$true)] [string]$GuestUser,
        [Parameter(Mandatory=$true)] [string]$GuestPassword
    )
    $unc = ('\\\\vmware-host\\Shared Folders\\{0}' -f $ShareName)
    $program = 'cmd.exe'
    $guestArgs = ('/c dir "{0}"' -f $unc)
    $args = @(
        '"{0}"' -f $VmxPath,
        '-gu', ('"{0}"' -f $GuestUser),
        '-gp', ('"{0}"' -f $GuestPassword),
        '"{0}"' -f $program,
        '"{0}"' -f $guestArgs
    )
    $res = Invoke-RiDVmrun -VmrunPath $VmrunPath -Command 'runProgramInGuest' -Arguments $args -AlwaysRun -CaptureOutput
    if ($null -eq $res) { return $false }
    return ($res.ExitCode -eq 0)
}
