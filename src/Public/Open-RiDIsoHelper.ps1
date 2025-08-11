function Open-RiDIsoHelper {
    <#
    .SYNOPSIS
        Guides the user through obtaining or selecting a Windows ISO.

    .DESCRIPTION
        Interactively prompts the user to specify whether an ISO is
        already available.  If so, opens a file selection dialog and
        validates the chosen file.  Otherwise offers to open the
        official Microsoft download page in the default browser or to
        invoke an automated download via the embedded Fido script (not
        yet implemented).  Returns the path to the ISO or `$null` if
        cancelled.
    #>
    [CmdletBinding()] param()

    Write-Host 'Windows ISO acquisition' -ForegroundColor Cyan
    Write-Host '----------------------' -ForegroundColor Cyan
    
    # Ask user if they already have an ISO
    $hasIso = Read-Host 'Do you already have a Windows ISO? [Y/N]'
    if ($hasIso -match '^[Yy]') {
        # Let user pick the file via open file dialog
        $path = Show-RiDOpenFileDialog -Filter 'ISO files (*.iso)|*.iso|All files (*.*)|*.*'
        if ($null -eq $path) {
            Write-Warning 'No file selected. Aborting ISO helper.'
            return $null
        }
        if (-not (Test-Path -Path $path)) {
            Write-Warning "The selected file does not exist: $path"
            return $null
        }
        if ([System.IO.Path]::GetExtension($path) -ne '.iso') {
            Write-Warning 'The selected file does not have an .iso extension.'
        }
        return $path
    }

    # Offer guided or automated download
    $choice = Read-Host 'ISO not found. Would you like a guided download [G], automated download [A] or cancel [C]?'
    switch ($choice.ToUpper()) {
        'G' {
            Write-Host 'Opening Microsoft Windows download page in your browser...' -ForegroundColor Cyan
            # Choose OS version
            $osChoice = Read-Host 'Which version do you need? [10/11]'
            switch ($osChoice) {
                '10' { $url = 'https://www.microsoft.com/software-download/windows10' }
                '11' { $url = 'https://www.microsoft.com/software-download/windows11' }
                default {
                    Write-Warning 'Invalid selection.'
                    return $null
                }
            }
            Open-RiDBrowser -Url $url
            Write-Host 'Follow the instructions on the Microsoft page to download the ISO. Once downloaded, run Open-RiDIsoHelper again and select the file.' -ForegroundColor Yellow
            return $null
        }
        'A' {
            Write-Host 'Automated download via Fido is not yet implemented.' -ForegroundColor Yellow
            return $null
        }
        default {
            Write-Host 'Cancelling ISO helper.'
            return $null
        }
    }
}