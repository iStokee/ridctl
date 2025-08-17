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

Refer to `USAGE.md` for a quick start and examples. The host menu includes an Options pane to configure defaults (download folder, ISO options, templates, shared folder, vmrun path, and VM defaults such as destination base, CPU, memory, disk, and method). First‑run prompts for key values and uses sensible defaults.
ISO defaults (`Iso.Release`, `Iso.Edition`, `Iso.Arch`) are used by the automated helper and can be set via Options or at runtime.

Defaults: the shared folder host path is `C:\RiDShare` (created on first run if missing) and the shared folder name is `rid`.

Public cmdlets support native `-WhatIf/-Confirm` (safe by default); private helpers may still use `-Apply` internally where noted.

Default-first UX: on first run, ridctl offers to either accept sensible defaults immediately or walk through a setup wizard. You can adjust anything later in Options.

## Readiness Banner

When you run `Show-RiDMenu` on the host, a readiness banner appears above the status cards to quickly indicate if you can proceed:

- VMware Workstation: Installed/Missing (and version when detected). Missing is fatal for VMware flows.
- Virtualization: Ready/Conflicted/Not Ready.
  - Ready: CPU VT is enabled and no blocking features detected.
  - Conflicted: VT is enabled, but Windows features like Hyper-V, Virtual Machine Platform, Windows Hypervisor Platform, Device Guard/VBS, or Memory Integrity (HVCI) are enabled.
  - Not Ready: CPU/BIOS virtualization is disabled or not supported.
- Next steps: Use `Test-RiDVirtualization -Detailed` for actionable guidance (disable conflicting features, `bcdedit /set hypervisorlaunchtype off`, turn off Memory Integrity, reboot).

Example messages:
- Ready: VMware installed; virtualization OK. (v17.x)
- VMware Workstation missing — install to continue.
- Conflicted: Hyper-V, Virtual Machine Platform, Windows Hypervisor Platform. See Test-RiDVirtualization for details.

## Registered VMs

For a smoother experience, you can register existing VMs with friendly names and manage them from the menu:
- Register: `Register-RiDVM -Name <friendly> -VmxPath <path>`
- List: `Get-RiDVM` (or filter with `-Name`)
- Remove: `Unregister-RiDVM -Name <friendly>`

In `Show-RiDMenu` (host), choose `7) Registered VMs` to:
- See your registered list (or be prompted to register one if empty)
- Select an index to Start, Stop, or Snapshot
- Use `r` to register another or `u` to unregister

## Quick Start

```pwsh
Import-Module ./src -Force
Show-RiDMenu
```

Highlights:
- First run configures defaults (Downloads folder, ISO defaults, `C:\RiDShare` share, templates, vmrun path, and VM defaults) and creates the share directory if needed. Status cards reflect readiness (Shared Folder turns green when present).
- Sync scripts from the host: `Sync-RiDScripts -ToShare -DryRun` then confirm with `-Confirm:$true` from the menu or cmdline.
- Create a new VM via menu or `New-RiDVM` (auto chooses vmcli if available or vmrun clone fallback). The menu pre-fills values from `VmDefaults` and suggests `C:\VMs\<Name>` as the destination.

See `docs/USAGE.md` for detailed flows (ISO helper, VM creation, share repair, guest init, and sync).
