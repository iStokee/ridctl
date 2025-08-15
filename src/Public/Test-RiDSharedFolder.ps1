function Test-RiDSharedFolder {
    <#
    .SYNOPSIS
        Verifies that a VMware shared folder is accessible inside the guest.

    .DESCRIPTION
        Uses vmrun to execute a simple directory listing in the guest against
        the UNC path \\vmware-host\Shared Folders\<ShareName>. Returns $true on
        success (exit code 0), $false otherwise. This operation is read-only.

    .PARAMETER VmxPath
        Path to the .vmx file of the target VM.

    .PARAMETER ShareName
        Name of the shared folder as configured for the VM.

    .PARAMETER GuestUser
        Guest OS username to authenticate with.

    .PARAMETER GuestPassword
        Password for the guest user.

    .EXAMPLE
        PS> Test-RiDSharedFolder -VmxPath 'C:\VMs\MyVM\MyVM.vmx' -ShareName 'rid' -GuestUser 'User' -GuestPassword 'Passw0rd!'
    #>
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)] [string]$VmxPath,
        [Parameter(Mandatory=$true)] [string]$ShareName,
        [Parameter(Mandatory=$true)] [string]$GuestUser,
        [Parameter(Mandatory=$true)] [string]$GuestPassword
    )
    $tools = Get-RiDVmTools
    if (-not $tools.VmrunPath) { Write-Error 'vmrun not found.'; return $false }
    return Test-RiDSharedFolderInGuest -VmrunPath $tools.VmrunPath -VmxPath $VmxPath -ShareName $ShareName -GuestUser $GuestUser -GuestPassword $GuestPassword
}

