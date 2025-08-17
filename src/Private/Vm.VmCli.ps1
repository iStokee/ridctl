<#
    Wrapper functions around the VMware Workstation CLI tool (vmcli)
    introduced with Workstation 17.  These functions will handle
    creating new VMs, configuring hardware, attaching ISOs and
    performing other operations.  At this stage they simply raise
    a warning when called to indicate missing functionality.
#>
function Invoke-RiDVmCliCommand {
    <#
    .SYNOPSIS
        Runs a vmcli command.

    .DESCRIPTION
        Wraps invocation of the VMware vmcli.exe command with the
        provided arguments.  In this scaffold it writes the command
        that would be executed without actually launching vmcli.
    #>
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)] [string]$VmCliPath,
        [Parameter(Mandatory=$true)] [string]$Arguments,
        [Parameter()] [switch]$Apply,
        [Parameter()] [switch]$CaptureOutput
    )
    if (-not $Apply) {
        Write-Host "[vmcli] $VmCliPath $Arguments" -ForegroundColor DarkCyan
        return $null
    }
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $VmCliPath
        $psi.Arguments = $Arguments
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $proc = [System.Diagnostics.Process]::Start($psi)
        $stdout = $proc.StandardOutput.ReadToEnd()
        $stderr = $proc.StandardError.ReadToEnd()
        $proc.WaitForExit()
        if ($CaptureOutput) { return [pscustomobject]@{ ExitCode = $proc.ExitCode; Stdout = $stdout; Stderr = $stderr } }
        if ($proc.ExitCode -ne 0) { Write-Error ("vmcli exited with code {0}: {1}" -f $proc.ExitCode, $stderr) }
        return $proc.ExitCode
    } catch {
        Write-Error "Failed to invoke vmcli: $_"
        return $null
    }
}

function New-RiDVmCliVM {
    <#
    .SYNOPSIS
        Creates a new VM using vmcli.

    .DESCRIPTION
        As part of the scaffold this function only prints the vmcli
        commands that would be used to create a new VM.  Later
        implementations will call Invoke-RiDVmCliCommand to perform
        actual operations.
    #>
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)] [string]$VmCliPath,
        [Parameter(Mandatory=$true)] [string]$Name,
        [Parameter(Mandatory=$true)] [string]$DestinationPath,
        [Parameter(Mandatory=$true)] [int]$CpuCount,
        [Parameter(Mandatory=$true)] [int]$MemoryMB,
        [Parameter(Mandatory=$true)] [int]$DiskGB,
        [Parameter()] [string]$IsoPath,
        [Parameter()] [switch]$Apply
    )
    Write-Host "Preparing to create VM '$Name' at '$DestinationPath' using vmcli." -ForegroundColor Cyan
    if (-not (Test-Path -Path $DestinationPath)) {
        if ($Apply) {
            try { New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null } catch { Write-Error "Failed to create destination: $_"; return $null }
        } else {
            Write-Host ('[fs] New-Item -ItemType Directory -Path "{0}" -Force' -f $DestinationPath) -ForegroundColor DarkCyan
        }
    }
    $args = ('vm create --name "{0}" --cpus {1} --memory {2} --disk-size {3} --path "{4}"' -f $Name, $CpuCount, $MemoryMB, $DiskGB, $DestinationPath)
    if ($IsoPath) { $args += (' --iso "{0}"' -f $IsoPath) }
    $rc = Invoke-RiDVmCliCommand -VmCliPath $VmCliPath -Arguments $args -Apply:$Apply
    if ($Apply -and $rc -ne 0) { Write-Error 'vmcli create failed.'; return $null }
    # Return expected VMX path if created under destination
    $vmx = Join-Path -Path $DestinationPath -ChildPath ('{0}.vmx' -f $Name)
    return $vmx
}
