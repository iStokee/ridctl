# RiDCTL Development Checklist

> Single source of truth for "what to do next." Work top‑to‑bottom unless a task is blocked.  
> Conventions: run in **PowerShell 7+** on Windows. Use `-Apply` to perform real changes; otherwise commands run in **dry‑run** mode.

## Legend
- [ ] = not started · [~] = in progress · [x] = done
- “How to test” lists quick steps to verify the milestone.

---

## Pre‑flight
- [ ] **Repo sanity**
  - Ensure folders exist: `src/Public`, `src/Private`, `docs`, `tests`, `third_party`.
  - Ensure `ridctl.psd1/psm1` load without errors (`Import-Module .\src\ridctl.psd1 -Force`).

- [ ] **Config defaults**
  - Implement `Get/Set-RiDConfig` (JSON in `%UserProfile%\.ridctl\config.json`) for:
    - `Iso.DownloadDir`, `Vm.TemplatePath`, `Vm.TemplateSnapshot`, `Share.Name`, `Share.HostPath`.
  - **How to test:** Set values, restart shell, re‑read config, confirm persistence.

---

## M1 — Status Cards & Environment Banner
- [ ] Implement `src/Private/Ui.Tui.ps1` with helpers to render colored status lines/cards.
- [ ] Extend `Get-RiDStatus` to surface: `Role` (Host/Guest), `Virtualization.OK`, `IsoAvailable`, `SharedFolder.Ok`, `Sync.Status`.
- [ ] Update `Show-RiDMenu` to display the banner + cards with green/yellow/red indicators.
- **How to test:** Run `Show-RiDMenu` on host and guest; confirm adaptive options and colorized status.

## M2 — Virtualization Readiness UX Polish (Host)
- [ ] Keep BIOS web‑search: `"<manufacturer> <model> enable virtualization in BIOS"`.
- [ ] When conflicts found (Hyper‑V, VMP, WSL, HVCI, WHPX), print a one‑line **Next steps** summary and non‑zero exit code.
- **How to test:** Enable Hyper‑V; run `Test-RiDVirtualization`; verify conflicts + actionable summary. Disable; verify clean pass.

## M3 — ISO Helper: Automated Download
- [ ] Implement `Invoke-RiDFidoDownload -Version <win10|win11> -Language <en-US> -Destination <dir>`.
- [ ] Wire `Open-RiDIsoHelper` “Automated” path to call the above and return a local ISO path.
- **How to test:** Select Automated; verify the ISO appears in download dir; path echoed back. Hash the file (optional).

## M4 — VM Creation via vmrun (Clone from Template)
- [ ] Implement `Clone-RiDVmrunTemplate -TemplateVmx -Snapshot -TargetDir -Name [-Apply]` with robust error handling.
- [ ] Apply VMX edits via `Set-RiDVmxSettings` (CPU, Memory, ISO attach, guest OS type).
- **How to test:** With a valid template snapshot, run with `-Apply`; confirm new VM folder, edited VMX, and `vmrun start` boots.

## M5 — VM Creation via vmcli (Fresh Create)
- [ ] Implement `Invoke-RiDVmCliCommand` wrapper and `New-RiDVmCliVM` (supports `--iso` attach).
- [ ] `New-RiDVM -Method auto` chooses vmcli when present; else falls back to vmrun clone.
- **How to test:** On Workstation 17+ with `vmcli`, run with `-Apply`; confirm a bootable fresh VM is created.

## M6 — Shared Folder Configure & Verify (Host + Guest)
- [ ] Finalize `Enable-RiDSharedFolder`/`Repair-RiDSharedFolder` (quotes, logging, `-Apply` path).
- [ ] Add guest‑side verification helper (via Tools: `vmrun -gu/-gp runProgramInGuest` to check `\\vmware-host\Shared Folders\<Name>` or a known sentinel file).
- [ ] Report `Get-RiDStatus.SharedFolder.Ok` accordingly and surface in TUI.
- **How to test:** Break the share, run Repair, verify guest sees the path; status turns green.

## M7 — Guest Configure (Java + RiD)
- [ ] `Initialize-RiDGuest` installs 7‑Zip, optionally Java; downloads RiD archive; extracts to target; prints launch instructions.
- [ ] Add `-NoDownload` to use a pre‑seeded archive path.
- **How to test:** On a clean VM, run command end‑to‑end; verify tools installed and RiD extracted.

## M8 — Sync Engine v1 (Host ↔ Share)
- [ ] Implement `Compare-RiDFiles` (timestamp/size/hash modes; default timestamp+size).
- [ ] Implement `Invoke-RiDSync` with directions: `FromShare`, `ToShare`, `Bidirectional`; support `-DryRun`, `-ResolveConflicts`, `-LogPath`.
- [ ] `Sync-RiDScripts` (public) prints concise summary and exit code; honors excludes from config.
- **How to test:** Create asymmetric files; run each direction with `-DryRun` (prints plan) and with `-Apply` (performs).

## M9 — Utilities Polish
- [ ] Ensure `Start/Stop/Checkpoint-RiDVM` forward `-Apply` and show clear errors; add smoke tests.
- **How to test:** Start/stop a known VM; create a snapshot; verify outcomes and messages.

## M10 — Menu Wiring for Full Flows
- [ ] Host “Create new VM” menu calls ISO helper if `-IsoPath` not provided; confirms before any `-Apply` action.
- [ ] Guest menu offers “Initialize guest” and “Sync Scripts” only.
- **How to test:** From menu, perform the host new‑VM flow end‑to‑end to a booting VM; perform guest init afterward.

## M11 — Config Persistence & Defaults
- [ ] On first run, prompt for key defaults; save via `Set-RiDConfig`.
- [ ] Subsequent runs auto‑use saved defaults; menu shows them.
- **How to test:** Delete config; run; set defaults; re‑run and confirm auto‑population.

## M12 — Tests & CI
- [ ] Add Pester tests for: ISO helper (returns file), VMX edits (idempotent), vmrun/vmcli command lines (mocked), virtualization conflict mapping, sync dry‑run summary.
- [ ] Add ScriptAnalyzer step; fix violations.
- **How to test:** `Invoke-Pester` passes; CI workflow on Windows runner is green.

## M13 — Docs Replacing the Two Guides
- [ ] Expand `docs/USAGE.md` with E2E flows: “from zero to running VM,” “repair share,” “guest configure,” “sync both ways.”
- [ ] Update `docs/MIGRATION.md` with concrete steps once M4–M6 are complete.
- **How to test:** A fresh user follows `USAGE.md` to success without referencing the Google Sites guides.

---

## Working Notes / Ops
- Keep commits small and reference the checklist item (e.g., `M4: implement vmrun clone apply path`).
- When blocking on a step, leave a note in `notes/YYYY‑MM‑DD.md` (template below) and proceed to the next unblocked item.

---

## Quick Commands (for reference)

```pwsh
# Import the module locally
Import-Module (Join-Path $PSScriptRoot 'src\ridctl.psd1') -Force

# Show menu
Show-RiDMenu

# Virtualization check
Test-RiDVirtualization

# ISO helper (automated)
Open-RiDIsoHelper -Automated

# Create VM (auto method)
New-RiDVM -Name 'rid-win10' -Cpu 4 -MemoryGB 8 -Apply

# Shared folder repair
Repair-RiDSharedFolder -VmPath 'C:\VMs\rid-win10\rid-win10.vmx' -ShareName 'rid' -HostPath 'D:\rid-share' -Apply

# Guest initialize (run inside VM)
Initialize-RiDGuest -InstallJava -RidZipUrl '<your-zip-url>'
```
