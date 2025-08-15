function Register-RiDVM {
    <#
    .SYNOPSIS
        Registers an existing VM by friendly name.

    .DESCRIPTION
        Adds or updates an entry in the user's RiD configuration so
        that commands and the menu can reference the VM by name rather
        than repeatedly entering a .vmx path.

    .PARAMETER Name
        Friendly name to identify the VM (must be unique).

    .PARAMETER VmxPath
        Filesystem path to the VM's .vmx file.

    .PARAMETER ShareName
        Optional default shared folder name associated with this VM.

    .PARAMETER HostPath
        Optional default host path for the shared folder.

    .PARAMETER Notes
        Optional note for display.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true)] [string]$Name,
        [Parameter(Mandatory=$true)] [string]$VmxPath,
        [string]$ShareName,
        [string]$HostPath,
        [string]$Notes
    )

    try {
        $entry = @{
            Name      = $Name
            VmxPath   = $VmxPath
            ShareName = $ShareName
            HostPath  = $HostPath
            Notes     = $Notes
        }

        $null = Add-RiDVmRegistryEntry -Entry $entry
        # Return the newly registered entry (handy in pipelines/tests)
        return (Get-RiDVmRegistry | Where-Object { $_.Name -eq $Name } | Select-Object -First 1)
    } catch {
        Write-Error $_
    }
}
