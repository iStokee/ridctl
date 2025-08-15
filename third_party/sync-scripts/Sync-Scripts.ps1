# compares the script folder on the VM to the shared folder and copies the newer files to the other folder
function Synchronize-Folder {
    param (
        [string]$sourceFolder,
        [string]$destinationFolder
    )

    # get the list of files in the source folder
    $sourceFiles = Get-ChildItem -Path $sourceFolder -Recurse | Where-Object { 
        $_.Extension -ne '.ridf' -and $_.Extension -ne '.rid' }

    # copy the files to the destination folder if they don't exist or are newer    
    foreach ($file in $sourceFiles) {
        # Ensure the correct relative path is computed
        $relativePath = $file.FullName.Substring($sourceFolder.Length).TrimStart('\')

        # Form the correct destination path
        $destinationPath = Join-Path $destinationFolder $relativePath

        # Check if the file exists in the destination folder and if it is newer
        if (-not (Test-Path $destinationPath) -or ($file.LastWriteTime -gt (Get-Item $destinationPath).LastWriteTime)) {
            Copy-Item -Path $file.FullName -Destination $destinationPath -Force
        }
    }
}

# Define the paths
$vmDirectoryPath = "G:\VM Share\RiDSharedScripts"
$sharedFolderPath = "\\filesvr.tnt.co\mediashare\RiD\Bots"
####################

# Check if VM directory is empty
$vmDirectoryEmpty = -not (Get-ChildItem -Path $vmDirectoryPath | Measure-Object).Count

# Check if the VM's script directly is empty
if ($vmDirectoryEmpty) {
    # If VM directory is empty, copy all contents from shared folder to VM
    Write-Host "VM directory is empty. Copying contents from shared folder."
    
    # Get all of the contents of the shared directory
    Get-ChildItem -Path $sharedFolderPath -Recurse | 
        ForEach-Object {
            $destinationPath = Join-Path $vmDirectoryPath $_.FullName.Substring($sharedFolderPath.Length)
            # Checks to see if there is already a folder in the script path with the name
            if (-not (Test-Path $destinationPath)) {
                $_ | Copy-Item -Destination $destinationPath -Recurse -Force
            }
        }
}

# If script directory is not empty
else {
    # Get the folder lists from both directories
    $vmFolders = Get-ChildItem -Path $vmDirectoryPath -Directory
    $sharedFolders = Get-ChildItem -Path $sharedFolderPath -Directory

    # Compare and synchronize folders from VM to Shared
    foreach ($vmFolder in $vmFolders) {
        $sharedFolder = $sharedFolders | Where-Object { $_.Name -eq $vmFolder.Name }
        
        if ($sharedFolder) {
            if ($vmFolder.LastWriteTime -gt $sharedFolder.LastWriteTime) {
                # VM folder is newer, synchronize from VM to Shared
                Synchronize-Folder -sourceFolder $vmFolder.FullName -destinationFolder $sharedFolder.FullName
            } else {
                # Shared folder is newer, synchronize from Shared to VM
                Synchronize-Folder -sourceFolder $sharedFolder.FullName -destinationFolder $vmFolder.FullName
            }
        } else {
            # Folder only exists on VM, copy to Shared
            Copy-Item -Path $vmFolder.FullName -Destination $sharedFolderPath -Recurse -Force
        }
    }

    # Compare and synchronize folders from Shared to VM
    foreach ($sharedFolder in $sharedFolders) {
        $vmFolder = $vmFolders | Where-Object { $_.Name -eq $sharedFolder.Name }

        if (-not $vmFolder) {
            # Folder only exists in Shared, copy to VM
            $destinationFolder = Join-Path $vmDirectoryPath $sharedFolder.Name
            Copy-Item -Path $sharedFolder.FullName -Destination $destinationFolder -Recurse -Force
        }
    }
}