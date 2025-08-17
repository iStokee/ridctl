@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'ridctl.psm1'

    # Version number of this module.
    ModuleVersion = '0.1.0'

    # ID used to uniquely identify this module
    GUID = 'd78a4af7-3a40-4d36-bec0-1995b884f740'

    # Author of this module
    Author = 'RiD Team'

    # Company or vendor of this module
    CompanyName = ''

    # Description of the functionality provided by this module
    Description = 'RiD control CLI/TUI for managing VMware Workstation VMs, ISO acquisition, shared folders and script syncing.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @()

    # Assemblies that must be loaded prior to importing this module
    RequiredAssemblies = @()

    # Functions to export from this module
    FunctionsToExport = @(
        'Show-RiDMenu',
        'Get-RiDStatus',
        'Test-RiDVirtualization',
        'Open-RiDIsoHelper',
        'Open-RiDGuestHelper',
        'Initialize-RiDGuest',
        'New-RiDVM',
        'Repair-RiDSharedFolder',
        'Sync-RiDScripts',
        'Show-RiDChecklist',
        'Start-RiDVM',
        'Stop-RiDVM',
        'Checkpoint-RiDVM',
        'Test-RiDSharedFolder',
        'Register-RiDVM',
        'Get-RiDVM',
        'Unregister-RiDVM'
        ,'Reset-RiDConfig'
    )

    # Cmdlets to export from this module
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport = '*'

    # Aliases to export from this module
    AliasesToExport  = '*'

    # Private data to pass to the module specified in RootModule/ModuleToProcess.
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('rid','vmware','cli','tui')
            # A URL to the license for this module.
            LicenseUri = ''
            # A URL to the main website for this project.
            ProjectUri = ''
            # ReleaseNotes of this module
            ReleaseNotes = 'Initial scaffold for RiD Control module.'
        }
    }
}
