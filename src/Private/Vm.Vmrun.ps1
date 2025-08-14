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
        [Parameter()] [switch]$Apply
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
    if (-not $Apply) {
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
        if ($p.ExitCode -ne 0) { Write-Error ("vmrun exited with code {0}: {1}" -f $p.ExitCode, $stderr) }
        return $p.ExitCode
    } catch {
        Write-Error "Failed to invoke vmrun: $_"
        return $null
    }
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
    $args = @('"{0}"' -f $TemplateVmx, '"{0}"' -f $DestinationVmx, 'full', ('-snapshot="{0}"' -f $SnapshotName))
    Invoke-RiDVmrun -VmrunPath $VmrunPath -Command 'clone' -Arguments $args -Apply:$Apply | Out-Null
}
