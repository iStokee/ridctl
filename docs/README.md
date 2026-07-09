# RiD Control

ridctl is a PowerShell module and command-line interface for provisioning and
managing the VMware Workstation VMs used for RiD workflows. It consolidates
the setup guides for creating a Windows guest and synchronising scripts
between host and guest into a single tool with a menu-driven UX.

> ridctl is **VMware-only**. Hyper-V helper code exists under
> `src/Private/Hv.*` but is parked and not wired into any public cmdlet;
> a config requesting `hyperv` falls back to VMware with a warning.

The module includes:

- Virtualization readiness checks (with actionable conflict summary).
- ISO helper with Fido automation:
  - Advanced selector (Version/Release/Edition/Language/Arch)
  - Headless URL retrieval and download with progress (HttpClient/BITS)
  - Interactive fallback with folder watch and auto-select
- VM creation via `New-RiDVM`:
  - **Clone** (preferred): `vmrun clone` from a golden-image template snapshot.
  - **Vanilla** (fallback): fresh Windows 11-ready VM (EFI + Secure Boot +
    software vTPM via `managedvm.autoAddVTPM`) that boots the installer ISO.
- VM operations via vmrun: start / stop / snapshot, with a friendly-name registry.
- Shared folder provision/repair (host) and guest verification.
- Sync v1 (host ↔ share): timestamp+size compare, dry-run, bidirectional.
- Guest Software Helper to bootstrap 7-Zip, Java JRE, package managers
  (Chocolatey/winget), RiD setup, and RuneScape installers.
- Guest debloat (`Optimize-RiDGuest`) for final golden-image prep: removes
  leftover Store apps, applies privacy/noise registry tweaks (telemetry,
  consumer features, Bing search, Copilot/Recall, widgets, Game DVR), and
  clears caches before you snapshot.
- Status & Checklist view for host and guest with safe, re-runnable actions.

Public cmdlets support native `-WhatIf`/`-Confirm` and are safe by default;
private helpers use `-Apply` internally.

## Quick Start

```pwsh
Import-Module ./src -Force
Show-RiDMenu
```

First run offers sensible defaults or a short wizard (ISO download dir
`C:\ISO`, share `C:\RiDShare` named `rid`, VM defaults, template paths); all
of it is editable later under Options.

Host menu:

```
1) Create new VM          clone from template, or fresh Windows 11 install
2) ISO Helper             download or select a Windows ISO
3) Registered VMs         start / stop / snapshot
4) Shared Folder          provision or repair the host<->guest share
5) Sync Scripts           sync local scripts with the share
6) Status & Checklist     detailed environment report
7) Options                defaults, template, paths
X) Exit
```

Guest menu (when run inside a VM): software helper, sync, checklist, and
debloat.

## The Golden-Image Workflow

The fastest way to spin up new VMs is cloning from a prepared template:

1. **Create the template once.** `New-RiDVM` with no template configured
   creates a fresh Windows 11-ready VM booting your ISO (get one via the ISO
   Helper). Install Windows, VMware Tools, and apply the Atlas playbook per
   the setup guide.
2. **Debloat inside the guest.** Run `Optimize-RiDGuest` (menu option 4 in
   the guest) to strip remaining Store apps, disable telemetry/consumer
   features so bloat doesn't return, and clear caches. Preview with `-WhatIf`.
3. **Snapshot.** Shut the guest down cleanly, then on the host:
   `Checkpoint-RiDVM -Name <template> -SnapshotName Clean -Confirm:$true`.
4. **Configure the template.** Set `Templates.DefaultVmx` and
   `Templates.DefaultSnapshot` in Options (or the first-run wizard).
5. **Clone forever.** From now on `New-RiDVM` (Method `auto` or `clone`)
   produces a ready VM in seconds via `vmrun clone`.

`New-RiDVM -Method vanilla` forces a fresh install even when a template is
configured.

## Readiness

When you run `Show-RiDMenu` on the host, the status cards summarize the
environment:

- **Virtualization**: Ready / Conflicted / Not Ready.
  - Conflicted: VT is enabled, but Windows features like Hyper-V, Virtual
    Machine Platform, Device Guard/VBS, or Memory Integrity (HVCI) may
    interfere with VMware. Use `Test-RiDVirtualization -Detailed` for
    actionable guidance.
- **VMware**: Installed / Missing (Missing is fatal for all VM flows).
- **Clone Template**: Configured / Not Set (Not Set means new VMs use the
  fresh-install path).
- **ISO** and **Shared Folder** availability.

Side-by-side tip: if Hyper-V features are present, enabling the Windows
Optional Feature `Windows Hypervisor Platform` generally improves VMware
compatibility on Windows 11.

## Registered VMs

Register existing VMs with friendly names and manage them from the menu:

- Register: `Register-RiDVM -Name <friendly> -VmxPath <path>`
- List: `Get-RiDVM` (or filter with `-Name`)
- Remove: `Unregister-RiDVM -Name <friendly>`
- Operate: `Start-RiDVM`, `Stop-RiDVM [-Hard]`, `Checkpoint-RiDVM` accept
  `-Name` or `-VmxPath`.

## Configuration

JSON config, merged in order System → User → Local (local overrides):

- `%ProgramData%\ridctl\config.json`
- `%UserProfile%\.ridctl\config.json`
- `<repo>\config.json` (developer convenience; or `RIDCTL_CONFIG` env var)

Key settings: `Iso.DefaultDownloadDir`, `Iso.Release/Edition/Arch`,
`Templates.DefaultVmx`, `Templates.DefaultSnapshot`, `Share.Name`,
`Share.HostPath`, `Vmware.vmrunPath`, and `VmDefaults.*` (destination base,
CPU, memory, disk, method `auto|clone|vanilla`).

See `docs/USAGE.md` for detailed flows (ISO helper, VM creation, share
repair, guest init, and sync).
