<#
    Implements logging facilities for RiD.  Writes to both the
    console and to rolling log files under the configured directory.
    At present this module defines a simple Write-RiDLog function
    that writes to the host only.
#>
function Write-RiDLog {
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)] [string]$Message,
        [Parameter()][ValidateSet('Verbose','Info','Warning','Error')] [string]$Level = 'Info'
    )
    switch ($Level) {
        'Verbose' { Write-Verbose $Message }
        'Info'    { Write-Host $Message -ForegroundColor White }
        'Warning' { Write-Warning $Message }
        'Error'   { Write-Error $Message }
    }
    # TODO: Persist messages to log file once configuration is available.
}