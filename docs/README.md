# RiD Control

ridctl is a PowerShell module and command‑line interface for managing
virtual machines used for development workflows. It consolidates
existing guides for provisioning a VMware Workstation guest and
synchronising scripts between host and guest into a single tool with a
menu‑driven UX.

This repository contains the source code for the module as well as
documentation, unit tests and build scripts. The module includes:

- Virtualization readiness checks (with actionable conflict summary).
- ISO helper with Fido automation:
  - Advanced selector (Version/Release/Edition/Language/Arch)
  - Headless URL retrieval and download with progress (HttpClient/BITS)
  - Interactive fallback with folder watch and auto‑select
- VM operations via vmrun/vmcli (start/stop/snapshot; new VM via clone or fresh create).
- Shared folder repair (host) and guest verification integration.
- Sync v1 (host ↔ share): timestamp+size compare, dry‑run, bidirectional.
- A first‑run setup that configures defaults and creates the default share path.
- Guest Software Helper to bootstrap 7‑Zip, Java JRE, package managers (Chocolatey/winget), RiD setup, and RuneScape installers.
- Status & Checklist view for host and guest with safe, re‑runnable actions.

Refer to `USAGE.md` for a quick start and examples. The host menu includes an Options pane to configure defaults (download folder, ISO options, templates, shared folder, vmrun path, and VM defaults such as destination base, CPU, memory, disk, and method). First‑run prompts for key values and uses sensible defaults.

Host menu layout:

1) Create new VM
2) ISO Helper
3) Registered VMs
4) Shared Folder: Provision/Repair
5) Sync Scripts
6) Status & Checklist
7) Options
X) Exit
ISO defaults (`Iso.Release`, `Iso.Edition`, `Iso.Arch`) are used by the automated helper and can be set via Options or at runtime.

Defaults: the shared folder host path is `C:\RiDShare` (created on first run if missing) and the shared folder name is `rid`. The default ISO download directory is `C:\ISO`.

Public cmdlets support native `-WhatIf/-Confirm` (safe by default); private helpers may still use `-Apply` internally where noted.

Default-first UX: on first run, ridctl offers to either accept sensible defaults immediately or walk through a setup wizard. You can adjust anything later in Options.

## Readiness

When you run `Show-RiDMenu` on the host, the status cards summarize whether VMware Workstation is installed and if virtualization is ready or conflicted.

- VMware Workstation: Installed/Missing (and version when detected). Missing is fatal for VMware flows.
- Virtualization: Ready/Conflicted/Not Ready.
  - Ready: CPU VT is enabled and no blocking features detected.
  - Conflicted: VT is enabled, but Windows features like Hyper-V, Virtual Machine Platform, Windows Hypervisor Platform, Device Guard/VBS, or Memory Integrity (HVCI) are enabled.
- Not Ready: CPU/BIOS virtualization is disabled or not supported.
- Next steps: Use `Test-RiDVirtualization -Detailed` for actionable guidance (disable conflicting features, `bcdedit /set hypervisorlaunchtype off`, turn off Memory Integrity, reboot).

## Choose Your Hypervisor

ridctl can operate with VMware Workstation or Hyper‑V:

- Config: set `Hypervisor.Type` to `vmware`, `hyperv`, or `auto` (default `vmware`).
- Auto preference: VMware when detected, else Hyper‑V when available.
- Start/Stop/Snapshot: public cmdlets route to the selected provider.

Side‑by‑side note: if both VMware and Hyper‑V are present, enabling the Windows Optional Feature `Windows Hypervisor Platform` generally improves compatibility for VMware on Windows 11.

Examples:

```pwsh
# Force Hyper-V
$cfg = Get-RiDConfig
$cfg.Hypervisor.Type = 'hyperv'
Set-RiDConfig -Config $cfg -Confirm:$true

# Create a Gen2 Hyper-V VM (defaults to "Default Switch")
New-RiDVM -Name Demo -DestinationPath 'C:\\VMs' -MemoryMB 4096 -CpuCount 2 -DiskGB 64 -WhatIf

# Start/Stop via provider routing
Start-RiDVM -Name Demo
Stop-RiDVM -Name Demo -Hard
```

## Registered VMs

For a smoother experience, you can register existing VMs with friendly names and manage them from the menu:
- Register: `Register-RiDVM -Name <friendly> -VmxPath <path>`
- List: `Get-RiDVM` (or filter with `-Name`)
- Remove: `Unregister-RiDVM -Name <friendly>`

In `Show-RiDMenu` (host), choose `3) Registered VMs` to:
- See your registered list (or be prompted to register one if empty)
- Select an index to Start, Stop, or Snapshot
- Use `r` to register another or `u` to unregister

## Quick Start

```pwsh
Import-Module ./src -Force
Show-RiDMenu
```

Highlights:
- First run configures defaults (ISO download dir `C:\ISO`, ISO defaults, `C:\RiDShare` share, templates, vmrun path, and VM defaults) and creates directories if needed. Status cards reflect readiness (Shared Folder turns green when present).
- Sync scripts from the host: `Sync-RiDScripts -ToShare -DryRun` then confirm with `-Confirm:$true` from the menu or cmdline.
- Create a new VM via menu or `New-RiDVM` (auto chooses vmcli if available or vmrun clone fallback). The menu pre-fills values from `VmDefaults` and suggests `C:\VMs\<Name>` as the destination.

See `docs/USAGE.md` for detailed flows (ISO helper, VM creation, share repair, guest init, and sync).
