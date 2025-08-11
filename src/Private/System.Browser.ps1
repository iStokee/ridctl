<#
    Provides a helper to open a web browser for the user.  Used to
    direct the user to BIOS search pages when virtualization is
    disabled or to open Microsoft ISO download pages.  Currently
    unimplemented.
#>
function Open-RiDBrowser {
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)] [string]$Url
    )
    Write-Warning 'Open-RiDBrowser is not yet implemented. Please manually navigate to: {0}' -f $Url
}