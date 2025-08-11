<#
    This file acts as the entry point for the RiD PowerShell module.  It
    dynamically loads all public and private script files from the module
    structure.  Functions defined in the Public folder will be exported
    automatically according to the module manifest.  Private scripts are
    loaded to provide helper functionality but remain internal to the
    module.
#>

# Ensure we're executing in the correct context
$moduleRoot = $PSScriptRoot

# Dot source all public functions.  These should be thin wrappers that
# call into private helper functions defined elsewhere.  As new
# functionality is added, drop additional *.ps1 files into the Public
# folder and they will be loaded automatically.
$publicScripts = Get-ChildItem -Path (Join-Path -Path $moduleRoot -ChildPath 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue
foreach ($script in $publicScripts) {
    . $script.FullName
}

# Dot source private helpers.  These are not exported but provide
# reusable functions used internally by exported cmdlets.  Keep the
# private surface minimal and well-documented.
$privateScripts = Get-ChildItem -Path (Join-Path -Path $moduleRoot -ChildPath 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue
foreach ($script in $privateScripts) {
    . $script.FullName
}