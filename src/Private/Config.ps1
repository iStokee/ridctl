<#
    Loads and saves RiD configuration files from the system and user
    locations.  Configuration is stored in JSON format in
    %ProgramData%\ridctl\config.json and overridden by
    %UserProfile%\.ridctl\config.json.  This stub returns an
    empty hashtable.
#>
function Get-RiDConfig {
    [CmdletBinding()] param()
    # TODO: Load configuration from disk and merge system/user scopes.
    return @{}
}

function Set-RiDConfig {
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)] [hashtable]$Config
    )
    # TODO: Write configuration to the user file path.
    Write-Warning 'Set-RiDConfig is not yet implemented.'
}