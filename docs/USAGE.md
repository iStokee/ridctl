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

On first run, ridctl offers to either accept sensible defaults immediately or walk through a simple setup wizard. The shared folder host path defaults to `C:\RiDShare` and is created if missing. You can change anything anytime under the Options menu. You can also try these implemented
building blocks:

- `Test-RiDVirtualization`: Runs host readiness checks and reports VT status and Windows feature conflicts.
- `Start-RiDVM -VmxPath <path> -WhatIf` or `-Confirm:$true`: Preview or confirm powering on a VM via `vmrun`.
- `Stop-RiDVM -VmxPath <path> [-Hard] -WhatIf` or `-Confirm:$true`: Preview or confirm powering off a VM via `vmrun`.
- `Checkpoint-RiDVM -VmxPath <path> -SnapshotName <name> -WhatIf` or `-Confirm:$true`: Preview or confirm taking a snapshot via `vmrun`.
- `Repair-RiDSharedFolder -VmxPath <path> -ShareName <name> -HostPath <path> -WhatIf` or `-Confirm:$true`: Preview or confirm enabling/configuring a shared folder via `vmrun`.
- `Initialize-RiDGuest [-InstallJava] [-RiDUrl <url>] [-Destination <path>] [-NoDownload] [-ArchivePath <file>]`: Installs 7‑Zip (and optionally Java), then either downloads the RiD archive or uses a pre‑seeded local archive and extracts it inside the guest.

Guest helper menu (run inside VM):
- `Open-RiDGuestHelper`: Interactive submenu to:
  - Install 7‑Zip
  - Install Java JRE (Temurin 17)
  - Install Chocolatey (package manager)
  - Install/Update winget (opens Microsoft Store App Installer)
  - Set up RiD (download or use pre‑seeded archive)
  - Download/launch RuneScape installers (RS3/OSRS; Jagex Launcher or Classic)
  Also accessible via `Show-RiDMenu` → Guest.

Note: The default ISO download directory across ridctl is `C:\\ISO`. You can change this in Options under `Iso.DefaultDownloadDir`.

## Status & Checklist

- `Show-RiDChecklist` opens a consolidated status view with colorized items and safe re‑run actions. It adapts to Host vs Guest:
  - Host: Virtualization readiness, VMware presence/version, vmrun/vmcli paths, shared folder host path, template VMX/snapshot configured and exists, ISO download directory, Fido script path/availability, registered VM count. Actions to re‑run virtualization test, open ISO helper, repair shared folder, sync, or install/update Fido.
  - Guest: Admin state, winget/choco/BITS availability, TLS enabled, 7‑Zip/Java presence, RiD folder exists, shared folder UNC. Actions to install Chocolatey, install/update winget (App Installer), install 7‑Zip/Java, or open the Guest Software Helper.
  - Accessible via `Show-RiDMenu` on both Host (option 6) and Guest (option 3).

Registered VMs (friendlier than typing .vmx paths):

- `Register-RiDVM -Name <friendly> -VmxPath <path>`: Registers an existing VM for easy reference.
- `Get-RiDVM` or `Get-RiDVM -Name <friendly>`: Lists or returns a registered VM.
- `Unregister-RiDVM -Name <friendly>`: Removes a VM from the registry.
- Most VM actions also accept `-Name` instead of `-VmxPath`:
  - `Start-RiDVM -Name <friendly> -WhatIf` or `-Confirm:$true`
  - `Stop-RiDVM -Name <friendly> [-Hard] -WhatIf` or `-Confirm:$true`
  - `Checkpoint-RiDVM -Name <friendly> -SnapshotName <name> -WhatIf` or `-Confirm:$true`
  - `Repair-RiDSharedFolder -Name <friendly> -ShareName <name> -HostPath <path> -WhatIf` or `-Confirm:$true`

Managing registered VMs in the menu:
- From `Show-RiDMenu` on host, choose `3) Registered VMs`.
- If none exist, you’ll be prompted to register one (name + `.vmx` path).
- When VMs are listed, select an index to perform actions: Start, Stop, Snapshot; or choose `r` to register another or `u` to unregister.

Creating a new VM (menu & vmrun clone):

```powershell
# Preview (no changes):
New-RiDVM -Name 'RiDVM1' -DestinationPath 'C:\VMs\RiDVM1' -CpuCount 2 -MemoryMB 4096 -Method vmrun -TemplateVmx 'C:\Templates\Win11Template\Win11Template.vmx' -TemplateSnapshot 'CleanOS' -WhatIf

# Execute with confirmation prompt:
New-RiDVM -Name 'RiDVM1' -DestinationPath 'C:\VMs\RiDVM1' -CpuCount 2 -MemoryMB 4096 -Method vmrun -TemplateVmx 'C:\Templates\Win11Template\Win11Template.vmx' -TemplateSnapshot 'CleanOS' -Confirm:$true
```

- If `-IsoPath` is omitted, the command can launch the ISO helper.
- With `-WhatIf`, clone and VMX edits are printed (dry‑run). With `-Confirm`, you are prompted before applying.

From the host menu, choose `1) Create new VM`. The flow pre-fills values from your saved defaults and you can press Enter for all prompts to get a working example:
- Name: defaults to `rid-YYYYMMDD_HHMM`
- Destination: suggests `Join-Path VmDefaults.DestinationBase <Name>` (e.g., `C:\VMs\<Name>`)
- CPU/Memory/Disk: prompts show `[default]` values from `VmDefaults`
- Method: defaults to `VmDefaults.Method` (`auto`, `vmcli`, or `vmrun`)

## Virtualization Readiness

When the host menu opens, a readiness banner summarizes whether VMware Workstation is installed and if virtualization is ready or conflicted. Use `Test-RiDVirtualization -Detailed` for a deeper breakdown.

Use `Test-RiDVirtualization [-Detailed]` on the host to verify readiness:

- Checks: CPU VT support and enabled state; Hyper-V, Virtual Machine Platform, Windows Hypervisor Platform; Hyper-V hypervisor active; hypervisor present now; Windows Sandbox; Core Isolation/Memory Integrity (HVCI); Device Guard/VBS; WSL (informational).
- Exit codes: 0 = Ready; 1 = Conflicted (features enabled that may block VMware); 2 = Not ready (CPU/BIOS) or VMware Workstation missing.
- Detailed view prints conflicts (or “None”), any reasons for “Not Ready,” and raw values for transparency.
- Next steps: A single line summarizes actions to disable conflicts (e.g., disable Hyper-V/Platform features, set `bcdedit /set hypervisorlaunchtype off`, turn off Memory Integrity); most changes require a reboot to take effect. If VMware Workstation is not detected, install it first.

## ISO Helper (Automated via Fido)

`Open-RiDIsoHelper` supports guided/manual and automated flows. Automated integrates with Fido and offers a fully headless path or an interactive fallback.

- Install Fido via ridctl:

```pwsh
Import-Module ./src -Force
Install-RiDFido -PersistConfig -Apply   # optional: -PinToCommit <sha>
```

Fido script location:

- By default, ridctl installs and looks for `third_party\fido\Fido.ps1`.
- You can override with `Iso.FidoScriptPath` in your config.

Example config:

```pwsh
$cfg = Get-RiDConfig
$cfg['Iso'] = @{
  'FidoScriptPath'     = 'D:\\tools\\fido\\Fido.ps1'
  'DefaultDownloadDir' = 'D:\\ISOs'
}
Set-RiDConfig $cfg
```

Advanced (non-interactive)

When you choose non-interactive, ridctl will:

- Offer an advanced selector sub‑menu to choose Version/Release/Edition/Language/Arch (lists come from Fido).
- Use your choices (and/or saved defaults) to request a direct Microsoft URL.
- If a direct URL is returned, download with progress (HttpClient or BITS).
- If not, fall back to the interactive Fido window and optionally watch your download directory to auto‑select the ISO when it appears.

You can set defaults in config (used for future runs):

```pwsh
$cfg = Get-RiDConfig
if (-not $cfg['Iso']) { $cfg['Iso'] = @{} }
$cfg['Iso']['Release'] = '23H2'   # or another release code
$cfg['Iso']['Edition'] = 'Pro'    # e.g., Home, Pro, Education
$cfg['Iso']['Arch']    = 'x64'    # x64, arm64
Set-RiDConfig $cfg
```

ridctl captures Fido's `-GetUrl` output, downloads to your destination, and returns the ISO path. If it can't obtain a URL, it falls back to the interactive flow.

Notes:
- Microsoft download links are time‑limited; start downloads promptly.
- Some environments may lack HttpClient; BITS fallback is used on Windows PowerShell.
- Tiny downloads (< 1 GB) are rejected to avoid saving error pages.
 
## Options Menu

From `Show-RiDMenu` on host, select `8) Options` to view/edit settings. You can always press Enter to keep the current value. Groups:
- ISO: `Iso.DefaultDownloadDir`, `Iso.FidoScriptPath`, `Iso.Release`, `Iso.Edition`, `Iso.Arch`
- Templates: `Templates.DefaultVmx`, `Templates.DefaultSnapshot`
- Shared Folder: `Share.Name`, `Share.HostPath` (default `C:\RiDShare`)
- VMware: `Vmware.vmrunPath`
- VM Defaults: `VmDefaults.DestinationBase`, `VmDefaults.CpuCount`, `VmDefaults.MemoryMB`, `VmDefaults.DiskGB`, `VmDefaults.Method`

Changes are saved via `Set-RiDConfig` and used on subsequent runs.

## Sync Scripts

Synchronise files between your local working directory and the VMware shared folder.

Defaults and config:
- Shared folder host path defaults to `C:\RiDShare` (created on first run).
- You can add default excludes in config at `Sync.Excludes` (wildcards on relative paths), e.g.:

```pwsh
$cfg = Get-RiDConfig
if (-not $cfg['Sync']) { $cfg['Sync'] = @{} }
$cfg['Sync']['Excludes'] = @('**/*.log','tmp/*','.git/**')
Set-RiDConfig $cfg
```

Examples:
- Dry-run, bidirectional (uses config excludes):
  - `Sync-RiDScripts -Bidirectional -DryRun`
- Apply from local to share (with confirmation):
  - `Sync-RiDScripts -ToShare -Confirm:$true`
- From share to local, with custom excludes and a log file:
  - `Sync-RiDScripts -FromShare -Excludes '**/*.bak','node_modules/**' -LogPath 'C:\logs\rid-sync.txt' -Confirm:$true`

Notes:
- v1 copies files only; no deletions.
- Conflict resolution: in bidirectional mode, add `-ResolveConflicts` to prefer the newer side; otherwise conflicts are skipped.

## Tool Detection

- `New-RiDVM -Method auto` prefers `vmcli` if available, otherwise uses `vmrun`.
- You can set `Vmware.vmrunPath` under Options so `vmrun` is detected even if it’s not on `PATH`.
## About VMX Paths

- A `.vmx` file is the VMware Workstation VM configuration file, usually located under your VM folder: `C:\VMs\MyVM\MyVM.vmx`.
- PowerShell does not treat backslashes as escapes — you do not need to double them. Use a normal Windows path.
- If the path contains spaces, wrap it in quotes.
- Examples:
  - `'C:\VMs\MyVM\MyVM.vmx'`
  - `"C:\VMs\My VM With Spaces\My VM With Spaces.vmx"`
- For clone operations, provide the destination folder. For management commands (start/stop/snapshot/share repair), provide the existing `.vmx` path.
