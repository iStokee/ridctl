# Migration Guide

This guide replaces the legacy host/guest setup instructions with the consolidated ridctl flows.

What’s covered now
- Host virtualization readiness checks with actionable guidance.
- ISO acquisition (guided + Fido automation).
- VM operations and creation (vmrun clone and vmcli fresh create).
- Shared folder repair on host and verification via Tools in the guest.
- Script sync v1 between host folder and VMware shared folder.

Quick migration path
1) Install and open menu
```pwsh
Import-Module ./src -Force
Show-RiDMenu
```

2) First run defaults
- ridctl initializes sensible defaults automatically. You can press Enter to accept prompts.
- Shared folder host path defaults to `C:\\RiDShare` and is created if missing.
- VM defaults (destination base, CPU, memory, disk, method) are pre-set and used by the “Create new VM” flow.
- You can revisit all settings under Options.

3) Register existing VM(s) for friendly names (optional but recommended)
```pwsh
Register-RiDVM -Name 'rid-win11' -VmxPath 'C:\\VMs\\rid-win11\\rid-win11.vmx'
Get-RiDVM
```

4) Ensure the shared folder is configured for your VM
```pwsh
# Preview then confirm
Repair-RiDSharedFolder -VmxPath 'C:\\VMs\\rid-win11\\rid-win11.vmx' -ShareName 'rid' -HostPath 'C:\\RiDShare' -WhatIf
Repair-RiDSharedFolder -VmxPath 'C:\\VMs\\rid-win11\\rid-win11.vmx' -ShareName 'rid' -HostPath 'C:\\RiDShare' -Confirm:$true
```

5) Sync scripts to the share
```pwsh
# Dry-run first, then confirm
Sync-RiDScripts -ToShare -DryRun
Sync-RiDScripts -ToShare -Confirm:$true
```

6) Optional — Create a new VM
- From the menu “Create new VM” (auto picks vmcli when available), or via:
```pwsh
New-RiDVM -Name 'rid-new' -DestinationPath 'C:\\VMs\\rid-new' -CpuCount 4 -MemoryMB 8192 -Confirm:$true
```

7) Optional — Initialize guest
- Inside the guest, you can run:
```pwsh
Initialize-RiDGuest -InstallJava -Destination "$env:USERPROFILE\RiD"
```
 This installs 7‑Zip (and optionally Java), downloads the RiD archive, and extracts it.

Notes
- Public cmdlets support `-WhatIf/-Confirm` for safe previews.
- Status cards in the menu show Shared Folder state (green once the host path exists on host; guest can verify via Tools).
- Excludes for Sync can be set in config `Sync.Excludes`.
- You can set `Vmware.vmrunPath` and `VmDefaults.*` under Options; creation prompts will use these defaults.
