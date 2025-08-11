function Get-RiDStatus {
    <#
    .SYNOPSIS
        Collects a snapshot of the current RiD environment.

    .DESCRIPTION
        Invokes helper functions in the private module to aggregate
        status information for the host or guest.  Used by the
        Show-RiDMenu function to display status cards.  As more
        features are implemented additional fields will be populated.

    .EXAMPLE
        PS> Get-RiDStatus | Format-List
    #>
    [CmdletBinding()] param()

    return Get-RiDAggregateStatus
}