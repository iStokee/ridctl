<#
    Guest-side debloat helpers used by Optimize-RiDGuest for final
    golden-image prep: removing leftover Store/AppX apps that the Atlas
    playbook does not cover, plus pre-snapshot cleanup of caches and
    temp files.
#>

function Get-RiDDebloatAppxTargets {
    <#
        Returns wildcard patterns of AppX package family names that are
        safe to remove from a RiD guest image. Deliberately excludes
        infrastructure packages (VCLibs, .NET runtimes, WebView, Store
        itself, App Installer/winget) that other software depends on.
    #>
    [CmdletBinding()] param()
    return @(
        'Microsoft.549981C3F5F10'            # Cortana
        'Microsoft.3DBuilder'
        'Microsoft.Microsoft3DViewer'
        'Microsoft.BingNews'
        'Microsoft.BingWeather'
        'Microsoft.BingSearch'
        'Microsoft.GetHelp'
        'Microsoft.Getstarted'
        'Microsoft.MicrosoftOfficeHub'
        'Microsoft.MicrosoftSolitaireCollection'
        'Microsoft.MicrosoftStickyNotes'
        'Microsoft.MixedReality.Portal'
        'Microsoft.Office.OneNote'
        'Microsoft.OutlookForWindows'
        'Microsoft.People'
        'Microsoft.PowerAutomateDesktop'
        'Microsoft.SkypeApp'
        'Microsoft.Todos'
        'Microsoft.Wallet'
        'Microsoft.WindowsAlarms'
        'Microsoft.WindowsCamera'
        'microsoft.windowscommunicationsapps' # Mail/Calendar
        'Microsoft.WindowsFeedbackHub'
        'Microsoft.WindowsMaps'
        'Microsoft.WindowsSoundRecorder'
        # Note: Xbox.TCUI / XboxIdentityProvider / XboxSpeechToTextOverlay are
        # intentionally NOT listed — removing them breaks Xbox/MS game sign-in
        # frameworks (Win11Debloat marks them unsafe too).
        'Microsoft.XboxApp'
        'Microsoft.XboxGameOverlay'
        'Microsoft.XboxGamingOverlay'
        'Microsoft.YourPhone'
        'Microsoft.ZuneMusic'
        'Microsoft.ZuneVideo'
        'MicrosoftCorporationII.MicrosoftFamily'
        'MicrosoftCorporationII.QuickAssist'
        'MicrosoftTeams'
        'MSTeams'
        'Clipchamp.Clipchamp'
        'Microsoft.GamingApp'                 # Xbox app (Win11)
        # Third-party sponsored/preinstalled apps (Win11Debloat defaults).
        # Harmless if absent; often present on OEM or consumer images.
        '7EE7776C.LinkedInforWindows'
        'SpotifyAB.SpotifyMusic'
        'BytedancePte.Ltd.TikTok'
        'Facebook.Facebook'
        'Facebook.InstagramBeta'
        'Facebook.Instagram'
        '4DF9E0F8.Netflix'
        'Disney.37853FC22B2CE'                # Disney+
        'AmazonVideo.PrimeVideo'
        'king.com.CandyCrushSaga'
        'king.com.CandyCrushSodaSaga'
        'king.com.BubbleWitch3Saga'
        '5A894077.McAfeeSecurity'
        '26720RandomSaladGamesLLC.HeartsDeluxe'
        'A278AB0D.MarchofEmpires'
        'A278AB0D.DisneyMagicKingdoms'
    )
}

function Get-RiDDebloatRegistryTweaks {
    <#
        Registry tweaks for golden-image prep, modeled on the default set of
        Raphire/Win11Debloat. Only high-confidence, policy-style tweaks that
        reduce noise/telemetry and stop Windows from re-adding bloat; no UI
        preference tweaks. Each entry: Path, Name, Value, Type, Description.
    #>
    [CmdletBinding()] param()
    return @(
        @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name='DisableWindowsConsumerFeatures'; Value=1; Type='DWord'
           Description='Stop auto-install of suggested Store apps (keeps clones clean)' }
        @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name='DisableSoftLanding'; Value=1; Type='DWord'
           Description='Disable Windows tips/suggestions' }
        @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name='AllowTelemetry'; Value=0; Type='DWord'
           Description='Minimize diagnostic data/telemetry' }
        @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'; Name='DODownloadMode'; Value=0; Type='DWord'
           Description='Disable Delivery Optimization peer downloads' }
        @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Dsh'; Name='AllowNewsAndInterests'; Value=0; Type='DWord'
           Description='Disable taskbar Widgets' }
        @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'; Name='AllowGameDVR'; Value=0; Type='DWord'
           Description='Disable Game DVR/background game recording' }
        @{ Path='HKCU:\Software\Policies\Microsoft\Windows\Explorer'; Name='DisableSearchBoxSuggestions'; Value=1; Type='DWord'
           Description='Disable Bing/web results in Start search' }
        @{ Path='HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot'; Name='TurnOffWindowsCopilot'; Value=1; Type='DWord'
           Description='Disable Windows Copilot' }
        @{ Path='HKCU:\Software\Policies\Microsoft\Windows\WindowsAI'; Name='DisableAIDataAnalysis'; Value=1; Type='DWord'
           Description='Disable Windows Recall snapshots' }
        @{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='RotatingLockScreenOverlayEnabled'; Value=0; Type='DWord'
           Description='Disable lock screen tips/ads' }
        @{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SystemPaneSuggestionsEnabled'; Value=0; Type='DWord'
           Description='Disable Start menu app suggestions' }
        @{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SilentInstalledAppsEnabled'; Value=0; Type='DWord'
           Description='Stop silent auto-install of sponsored apps (LinkedIn, Spotify, etc.)' }
        @{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='PreInstalledAppsEnabled'; Value=0; Type='DWord'
           Description='Disable preinstalled sponsored apps' }
        @{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='PreInstalledAppsEverEnabled'; Value=0; Type='DWord'
           Description='Disable preinstalled sponsored apps (permanent flag)' }
        @{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='OemPreInstalledAppsEnabled'; Value=0; Type='DWord'
           Description='Disable OEM preinstalled app promotions' }
        @{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-338388Enabled'; Value=0; Type='DWord'
           Description='Disable Start menu sponsored app suggestions' }
        @{ Path='HKCU:\System\GameConfigStore'; Name='GameDVR_Enabled'; Value=0; Type='DWord'
           Description='Disable Game Bar capture for current user' }
        @{ Path='HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'; Name='HiberbootEnabled'; Value=0; Type='DWord'
           Description='Disable fast startup so shutdowns are clean before snapshots' }
    )
}

function Set-RiDDebloatRegistryTweaks {
    [CmdletBinding()] param(
        [switch]$Apply
    )
    $applied = 0; $planned = 0; $failed = 0
    foreach ($t in (Get-RiDDebloatRegistryTweaks)) {
        if ($Apply) {
            try {
                if (-not (Test-Path -LiteralPath $t.Path)) { New-Item -Path $t.Path -Force | Out-Null }
                New-ItemProperty -LiteralPath $t.Path -Name $t.Name -Value $t.Value -PropertyType $t.Type -Force | Out-Null
                Write-Host ("[reg] {0} ({1}\{2} = {3})" -f $t.Description, $t.Path, $t.Name, $t.Value) -ForegroundColor DarkGray
                $applied++
            } catch {
                Write-Warning ("Failed tweak '{0}': {1}" -f $t.Description, $_.Exception.Message)
                $failed++
            }
        } else {
            Write-Host ("[reg] Would apply: {0}" -f $t.Description) -ForegroundColor DarkCyan
            $planned++
        }
    }
    [pscustomobject]@{ Applied=$applied; Planned=$planned; Failed=$failed }
}

function Invoke-RiDGuestDebloat {
    <#
    .SYNOPSIS
        Removes leftover Store apps and cleans caches for golden-image prep.

    .DESCRIPTION
        For each target pattern, removes installed AppX packages (all users)
        and the matching provisioned packages (so clones/new users don't get
        them back). Optionally performs pre-snapshot cleanup: temp folders,
        Delivery Optimization cache, and the recycle bin. Honors -Apply for
        the internal dry-run model; callers pass -Apply from ShouldProcess.
    #>
    [CmdletBinding()] param(
        [string[]]$KeepApps = @(),
        [switch]$SkipAppx,
        [switch]$SkipTweaks,
        [switch]$SkipCleanup,
        [switch]$Apply
    )

    $removed = 0; $planned = 0; $failed = 0

    if (-not $SkipAppx) {
        $targets = Get-RiDDebloatAppxTargets | Where-Object {
            $t = $_
            -not ($KeepApps | Where-Object { $t -like $_ })
        }

        $installed = @()
        $provisioned = @()
        try { $installed = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue } catch { }
        try { $provisioned = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue } catch { }

        foreach ($t in $targets) {
            foreach ($pkg in ($installed | Where-Object { $_.Name -like $t })) {
                if ($Apply) {
                    try {
                        Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
                        Write-Host ("[appx] Removed {0}" -f $pkg.Name) -ForegroundColor DarkGray
                        $removed++
                    } catch {
                        Write-Warning ("Failed to remove {0}: {1}" -f $pkg.Name, $_.Exception.Message)
                        $failed++
                    }
                } else {
                    Write-Host ("[appx] Would remove package {0}" -f $pkg.Name) -ForegroundColor DarkCyan
                    $planned++
                }
            }
            foreach ($pkg in ($provisioned | Where-Object { $_.DisplayName -like $t })) {
                if ($Apply) {
                    try {
                        Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction Stop | Out-Null
                        Write-Host ("[appx] Deprovisioned {0}" -f $pkg.DisplayName) -ForegroundColor DarkGray
                        $removed++
                    } catch {
                        Write-Warning ("Failed to deprovision {0}: {1}" -f $pkg.DisplayName, $_.Exception.Message)
                        $failed++
                    }
                } else {
                    Write-Host ("[appx] Would deprovision {0}" -f $pkg.DisplayName) -ForegroundColor DarkCyan
                    $planned++
                }
            }
        }
    }

    if (-not $SkipTweaks) {
        $tw = Set-RiDDebloatRegistryTweaks -Apply:$Apply
        $removed += $tw.Applied
        $planned += $tw.Planned
        $failed  += $tw.Failed
    }

    if (-not $SkipCleanup) {
        $tempDirs = @($env:TEMP, (Join-Path $env:WINDIR 'Temp')) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique
        foreach ($d in $tempDirs) {
            if ($Apply) {
                try {
                    Get-ChildItem -LiteralPath $d -Force -ErrorAction SilentlyContinue |
                        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Host ("[cleanup] Cleared {0}" -f $d) -ForegroundColor DarkGray
                } catch { Write-Verbose $_ }
            } else {
                Write-Host ("[cleanup] Would clear {0}" -f $d) -ForegroundColor DarkCyan
            }
        }
        if ($Apply) {
            try { Delete-DeliveryOptimizationCache -Force -ErrorAction SilentlyContinue } catch { }
            try { Clear-RecycleBin -Force -ErrorAction SilentlyContinue } catch { }
            Write-Host '[cleanup] Delivery Optimization cache and Recycle Bin cleared.' -ForegroundColor DarkGray
        } else {
            Write-Host '[cleanup] Would clear Delivery Optimization cache and Recycle Bin.' -ForegroundColor DarkCyan
        }
    }

    [pscustomobject]@{
        Removed = $removed
        Planned = $planned
        Failed  = $failed
        Applied = [bool]$Apply
    }
}
