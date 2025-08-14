# RiD Roadmap and Notes

## Phased Roadmap

1. Foundations
   - Environment detection (host vs guest), virtualization checks
   - Browser helper, configuration load/save, logging hooks
   - Safe dry-run defaults, vmrun wrappers with optional `-Apply`

2. ISO Flow
   - Guided ISO selection and validation
   - Stub automated Fido download (version/language selection)

3. VMware Operations (vmrun)
   - Start/stop/snapshot/shared folders (dry-run + `-Apply`)
   - Robust error handling and user prompts

4. VM Provisioning
   - Clone from template via vmrun
   - Scaffold vmcli support; parameterize CPU/memory/disk/ISO attach
   - Idempotency and validation

5. Sync Engine
   - Integrate `third_party/sync-scripts`
   - Unidirectional/bidirectional sync, dry-run, conflict strategies
   - Expand `Get-RiDStatus` coverage

6. TUI + UX
   - Adaptive menu (host/guest), status cards, confirmations
   - Progress output and friendly errors

7. Hardening
   - Pester tests, ScriptAnalyzer baselines
   - Edge cases, examples, and CI polish

## Working Notes

- RiD archive download (provided by user):
  - URL: https://www.robotzindisguise.com/g983njfg89Ahfh3q0afljf9ja0rokr3-1rjioRAJ93m/RiD.rar
  - Extraction requires 7-Zip.
- 7-Zip install options on Windows:
  - `winget install --id 7zip.7zip -e`
  - or `choco install -y 7zip` (if Chocolatey is available)
- Planned guest configuration:
  - Install 7-Zip, optionally Java (Temurin JRE via winget), download and extract RiD to `%USERPROFILE%\RiD` (default)
  - Future: install/import this module, Atlas integration (TBD)

---

## External Notes (imported)

The following notes (from a collaborator AI) align with our roadmap and expand on architecture and acceptance criteria:

### Project name & repos

- Top‑level repo: ridctl (PowerShell module + CLI/TUI)
- Submodule/vendor: iStokee/sync-scripts under `third_party/sync-scripts`

### Goals (single tool, replaces both guides)

1. Create new VM (VMware Workstation)
2. Virtualization readiness tool (host vs vm; BIOS/feature checks; tailored help)
3. Provision/repair VM shared folder
4. Enhanced script sync (share ⇄ vm), menu‑driven
5. One menu (“single pane”) adapting to host vs vm

### High‑level architecture

See repository layout under `src/Public` and `src/Private` with helpers for vmrun/vmcli/vmrest, ISO flows, sync, status, logging, and config. TUI modules (`Ui.Tui.ps1`, `Ui.Dialogs.ps1`) support rendering.

### Configuration keys (planned)

- Vmware.WorkstationPath, Vmware.vmrunPath, Vmware.vmcliPath, Vmware.vmrestPath
- Templates.DefaultVmx, Templates.DefaultSnapshot
- Iso.DefaultDownloadDir
- Share.Name, Share.HostPath
- Sync.DefaultLocalPath, Sync.Excludes
- Logging.Level, Logging.Path

### Exported commands (contracts) – acceptance points

- Show-RiDMenu: adaptive; colored status cards; numeric/keyboard selection
- Test-RiDVirtualization: host feature checks; BIOS help; exit codes 0/1/2
- Open-RiDIsoHelper: manual/guided/automated (Fido) flows; returns ISO path
- New-RiDVM: create via vmcli or clone via vmrun; shared folder pre‑enabled
- Repair-RiDSharedFolder: idempotent enable/remove/add; validate if possible
- Sync-RiDScripts: modes, dry‑run, conflict strategy; logs
- Utilities: Start/Stop/Checkpoint thin wrappers

### TUI behavior

- Host: New VM, Virtualization readiness, Shared folder, Sync, Utilities, Exit
- Guest: Sync, VM info, Exit
- Status cards: Virtualization | ISO | Shared Folder | Sync (green/yellow/red)

### Testing plan (high level)

- Unit (Pester): mock external tools/APIs; validate parameters and outputs
- Integration: smoke tests against Workstation install and template VM
- CI: lint + unit tests on Windows runner

### Milestones (indicative)

- M1: Skeleton menu, basic status, CI
- M2: ISO acquisition (guided + Fido)
- M3: VM creation (vmcli + vmrun clone fallback)
- M4: Shared folder provision/repair
- M5: Sync v2 integration
- M6: Polish & docs

