function Enable-RiDHvGuestService { [CmdletBinding()] param([Parameter(Mandatory)][string]$Name)
    try {
        $svc = Get-VMIntegrationService -VMName $Name -Name 'Guest Service Interface' -ErrorAction SilentlyContinue
        if ($svc -and -not $svc.Enabled) { Enable-VMIntegrationService -VMName $Name -Name 'Guest Service Interface' | Out-Null }
    } catch { }
}
function Copy-RiDHvToGuest { [CmdletBinding()] param([Parameter(Mandatory)][string]$Name,[Parameter(Mandatory)][string]$Source,[Parameter(Mandatory)][string]$Destination)
    Enable-RiDHvGuestService -Name $Name
    Copy-VMFile -Name $Name -SourcePath $Source -DestinationPath $Destination -FileSource Host -CreateFullPath
}
function Copy-RiDHvFromGuest { [CmdletBinding()] param([Parameter(Mandatory)][string]$Name,[Parameter(Mandatory)][string]$Source,[Parameter(Mandatory)][string]$Destination)
    Enable-RiDHvGuestService -Name $Name
    Copy-VMFile -Name $Name -SourcePath $Source -DestinationPath $Destination -FileSource Guest -CreateFullPath
}

