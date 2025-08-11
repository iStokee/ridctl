<#
    Provides functions to compare files by timestamp, size or hash for
    the synchronisation operations.  At present these functions
    return no meaningful data.
#>
function Compare-RiDFiles {
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)] [string]$Path1,
        [Parameter(Mandatory=$true)] [string]$Path2
    )
    Write-Warning 'Compare-RiDFiles is not yet implemented.'
    return $null
}