<#
    Embeds the Fido PowerShell script for automating Windows ISO
    downloads.  In the real implementation this file will vendor
    Microsoft Fido (Get-WindowsIso) and provide a wrapper function to
    select OS version and language.  Currently not implemented.
#>
function Invoke-RiDFidoDownload {
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)][ValidateSet('win10','win11')] [string]$Version,
        [Parameter(Mandatory=$true)] [string]$Language,
        [Parameter(Mandatory=$true)] [string]$Destination
    )
    Write-Warning 'Invoke-RiDFidoDownload is not yet implemented.'
    return $null
}