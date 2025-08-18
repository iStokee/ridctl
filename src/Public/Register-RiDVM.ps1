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
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName='ByVmware')]
    param(
        # Shared param (mandatory in both sets)
        [Parameter(ParameterSetName='ByVmware', Mandatory=$true)]
        [Parameter(ParameterSetName='ByHyperV', Mandatory=$true)]
        [string]$Name,

        # VMware parameter set: requires VMX path
        [Parameter(ParameterSetName='ByVmware', Mandatory=$true)]
        [string]$VmxPath,

        # Provider: optional for VMware, mandatory for Hyper-V; defaults resolved if omitted
        [Parameter(ParameterSetName='ByVmware')]
        [Parameter(ParameterSetName='ByHyperV', Mandatory=$true)]
        [ValidateSet('vmware','hyperv')]
        [string]$Provider,

        [string]$ShareName,
        [string]$HostPath,
        [string]$Notes
    )

    try {
        if ($PSCmdlet.ParameterSetName -eq 'ByHyperV' -and $Provider -and $Provider -ne 'hyperv') {
            throw "For ByHyperV parameter set, -Provider must be 'hyperv'."
        }
        if (-not $Provider) {
            try { $Provider = (Get-RiDProviderPreference) } catch { $Provider = 'vmware' }
        }

        # When Hyper-V provider is selected, omit VMX path in the registry.
        if ($Provider -eq 'hyperv') {
            $VmxPath = ''
        }
        $entry = @{
            Name      = $Name
            VmxPath   = $VmxPath
            Provider  = $Provider
            ShareName = $ShareName
            HostPath  = $HostPath
            Notes     = $Notes
        }

        if ($PSCmdlet.ShouldProcess($Name, 'Register VM')) {
            $null = Add-RiDVmRegistryEntry -Entry $entry
            return (Get-RiDVmRegistry | Where-Object { $_.Name -eq $Name } | Select-Object -First 1)
        }
    } catch {
        Write-Error $_
    }
}
