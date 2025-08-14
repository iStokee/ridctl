<#
    Provides a helper to open a web browser for the user.  Used to
    direct the user to BIOS search pages when virtualization is
    disabled or to open Microsoft ISO download pages.
#>
function Open-RiDBrowser {
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)] [string]$Url
    )
    try {
        # Primary: Start-Process with URL works on Windows PowerShell 5.1
        Start-Process -FilePath $Url -ErrorAction Stop | Out-Null
        return
    } catch {
        # Fallbacks by platform
        try {
            if ($env:OS -like '*Windows*') {
                # Use cmd to avoid issues with special chars
                Start-Process -FilePath cmd.exe -ArgumentList "/c","start","","$Url" -WindowStyle Hidden -ErrorAction Stop | Out-Null
                return
            }
        } catch {}
        try {
            # Linux
            if (Get-Command -Name xdg-open -ErrorAction SilentlyContinue) {
                Start-Process -FilePath xdg-open -ArgumentList $Url -ErrorAction Stop | Out-Null
                return
            }
        } catch {}
        try {
            # macOS
            if (Get-Command -Name open -ErrorAction SilentlyContinue) {
                Start-Process -FilePath open -ArgumentList $Url -ErrorAction Stop | Out-Null
                return
            }
        } catch {}
        Write-Warning ("Could not automatically open a browser. Please navigate to: {0}" -f $Url)
    }
}
