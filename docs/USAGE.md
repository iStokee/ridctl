# Quick Start

> **Note**
> The module is under active development. Several foundational
> features are available today, while others remain scaffolded.

To install the module once it is published to the PowerShell gallery:

```powershell
Install-Module -Name ridctl -Scope CurrentUser
Import-Module ridctl
Show-RiDMenu
```

This displays the menu scaffold. You can also try these implemented
building blocks:

- `Test-RiDVirtualization`: Runs host readiness checks and reports VT status and Windows feature conflicts.
- `Start-RiDVM -VmxPath <path> [-Apply]`: Prints or (with `-Apply`) powers on a VM via `vmrun`.
- `Stop-RiDVM -VmxPath <path> [-Hard] [-Apply]`: Prints or (with `-Apply`) powers off a VM via `vmrun`.
- `Checkpoint-RiDVM -VmxPath <path> -SnapshotName <name> [-Apply]`: Prints or (with `-Apply`) takes a snapshot via `vmrun`.
- `Repair-RiDSharedFolder -VmxPath <path> -ShareName <name> -HostPath <path> [-Apply]`: Prints or (with `-Apply`) enables and configures a shared folder via `vmrun`.
 - `Initialize-RiDGuest [-InstallJava] [-RiDUrl <url>] [-Destination <path>]`: Installs 7‑Zip (and optionally Java), downloads the RiD archive, and extracts it inside the guest.

Creating a new VM (vmrun clone):

```powershell
New-RiDVM -Name 'RiDVM1' -DestinationPath 'C:\VMs\RiDVM1' -CpuCount 2 -MemoryMB 4096 -Method vmrun -TemplateVmx 'C:\Templates\Win11Template\Win11Template.vmx' -TemplateSnapshot 'CleanOS' [-IsoPath 'C:\ISOs\Win11.iso'] [-Apply]
```

- If `-IsoPath` is omitted, the command can launch the ISO helper.
- Without `-Apply`, clone and VMX edits are printed (dry‑run) but not executed.

Without `-Apply`, commands run in dry‑run mode and only print the
`vmrun` commands that would be executed.
