function Show-RiDChecklist {
    <#
    .SYNOPSIS
      Shows a consolidated VM checklist with statuses and safe actions.

    .DESCRIPTION
      Displays a host or guest specific checklist with colorized statuses.
      Provides quick actions to re-run idempotent steps (install tools,
      fix configuration, open helpers). Designed to be re-runnable safely.
    #>
    [CmdletBinding()] param()

    $status = Get-RiDAggregateStatus
    while ($true) {
        Clear-Host
        Write-RiDHeader -Title 'RiD Control > Checklist'
        $ck = Get-RiDChecklistStatus
        Write-RiDChecklist -Checklist $ck
        Write-Host ''
        if (-not $status.IsVM) {
            Write-Host 'Actions (Host):' -ForegroundColor Green
            Write-Host '  1) Test virtualization (detailed)'
            Write-Host '  2) ISO helper'
            Write-Host '  3) Repair shared folder'
            Write-Host '  4) Sync scripts'
            Write-Host '  5) Install/Update Fido script'
            Write-Host '  X) Back'
            $sel = Read-Host 'Select an option'
            switch ($sel.ToUpper()) {
                '1' { try { Test-RiDVirtualization -Detailed | Out-Null } catch { Write-Error $_ }; Pause-RiD }
                '2' { try { $null = Open-RiDIsoHelper } catch { Write-Error $_ }; Pause-RiD }
                '3' {
                    try {
                        $vmx = Read-Host 'Path to VMX (or leave blank to cancel)'
                        if ($vmx) {
                            $cfg = Get-RiDConfig
                            $name = if ($cfg['Share'] -and $cfg['Share']['Name']) { [string]$cfg['Share']['Name'] } else { 'rid' }
                            $host = if ($cfg['Share'] -and $cfg['Share']['HostPath']) { [string]$cfg['Share']['HostPath'] } else { 'C:\\RiDShare' }
                            Repair-RiDSharedFolder -VmxPath $vmx -ShareName $name -HostPath $host -Confirm:$true
                        }
                    } catch { Write-Error $_ }
                    Pause-RiD
                }
                '4' {
                    try {
                        $dir = Read-Host 'Direction: FromShare (F), ToShare (T) or Bidirectional (B) [B]'
                        $isDry = -not (Read-RiDYesNo -Prompt 'Apply changes?' -Default No)
                        switch ($dir.ToUpper()) {
                            'F' { Sync-RiDScripts -FromShare -DryRun:$isDry }
                            'T' { Sync-RiDScripts -ToShare -DryRun:$isDry }
                            default { Sync-RiDScripts -Bidirectional -DryRun:$isDry }
                        }
                    } catch { Write-Error $_ }
                    Pause-RiD
                }
                '5' {
                    try {
                        $path = Install-RiDFido -PersistConfig -Apply
                        if ($path) { Write-Host ("Fido installed/updated at: {0}" -f $path) -ForegroundColor Green }
                        else { Write-Host 'Fido installation not completed.' -ForegroundColor Yellow }
                    } catch { Write-Error $_ }
                    Pause-RiD
                }
                'X' { return }
                default { }
            }
        } else {
            Write-Host 'Actions (Guest):' -ForegroundColor Green
            Write-Host '  1) Install Chocolatey'
            Write-Host '  2) Install/Update winget (App Installer)'
            Write-Host '  3) Install 7-Zip'
            Write-Host '  4) Install Java JRE (Temurin 17)'
            Write-Host '  5) Open Guest Software Helper'
            Write-Host '  X) Back'
            $sel = Read-Host 'Select an option'
            switch ($sel.ToUpper()) {
                '1' { try { $null = Install-RiDChocolatey } catch { Write-Error $_ }; Pause-RiD }
                '2' { try { $null = Install-RiDWinget } catch { Write-Error $_ }; Pause-RiD }
                '3' { try { $null = Install-RiD7Zip } catch { Write-Error $_ }; Pause-RiD }
                '4' { try { $null = Install-RiDJavaJre } catch { Write-Error $_ }; Pause-RiD }
                '5' { try { Open-RiDGuestHelper } catch { Write-Error $_ }; Pause-RiD }
                'X' { return }
                default { }
            }
        }
    }
}
