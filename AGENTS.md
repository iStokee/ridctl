# Repository Guidelines

## Project Structure & Module Organization
- `src/` PowerShell module:
  - `ridctl.psd1` manifest, `ridctl.psm1` loader (auto‑loads `Public/` and `Private/`).
  - `Public/` exported cmdlets (one function per file, name = filename).
  - `Private/` internal helpers (domain‑grouped: `Vm.*`, `Iso.*`, `System.*`, etc.).
- `tests/` Pester tests (unit in `tests/unit`).
- `docs/` README, USAGE, PLAN (roadmap/notes; see below).
- `third_party/` external integrations (e.g., `sync-scripts`).

## Architecture & Roadmap Snapshot
- Layers: CLI/TUI (`Show-RiDMenu`) → Public cmdlets → Private helpers (`Vm.Vmrun`, `Vm.VmCli`, `Iso.*`, `Sync.*`, `Status.*`).
- Near‑term milestones: ISO helper (guided/automated), vmrun/vmcli VM creation, shared‑folder repair, sync integration, status cards. For details, read `docs/PLAN.md`.

## Build, Test, and Development Commands
- Import locally: `Import-Module ./src -Force`
- Run menu: `Show-RiDMenu`
- Lint: `Invoke-ScriptAnalyzer -Path src -Recurse -Severity Warning`
- Tests: `Invoke-Pester -Path tests/unit -PassThru`
- Example (dry‑run apply model): `Start-RiDVM -VmxPath 'C:\VMs\VM\VM.vmx' [-Apply]`

## Coding Style & Naming Conventions
- PowerShell 5.1 compatible; 4‑space indentation; comment‑based help for public cmdlets.
- Cmdlets in PascalCase with verb‑noun (e.g., `New-RiDVM`); one public function per file under `Public/`.
- Private helpers grouped by area (e.g., `Vm.Vmrun.ps1`); internal functions prefixed `Get‑RiD*`, `Invoke‑RiD*`, etc.
- Keep changes minimal and focused; prefer idempotent operations and safe dry‑run with `-Apply` to commit.

## Configuration Keys (user/system)
- Files: `%ProgramData%\\ridctl\\config.json`, `%UserProfile%\\.ridctl\\config.json`.
- Common keys: `Templates.DefaultVmx`, `Templates.DefaultSnapshot`, `Vmware.vmrunPath`, `Iso.DefaultDownloadDir`, `Share.Name`, `Share.HostPath`.

## Testing Guidelines
- Framework: Pester. Place unit tests in `tests/unit` as `Name.Tests.ps1`.
- Mock external tools (`vmrun`, `winget`, downloads) in unit tests.
- Run locally on Windows PowerShell. CI runs on Windows via GitHub Actions.

## Commit & Pull Request Guidelines
- Commits: concise, imperative summary; reference issues (`Fixes #123`) where relevant.
- PRs: include purpose, scope, testing notes, and any screenshots/logs. Link related issues.
- Ensure `Invoke-Pester` and `Invoke-ScriptAnalyzer` pass before requesting review.

## Security & Configuration Tips
- Destructive operations require `-Apply`; default behavior is dry‑run.
- Configuration files: `%ProgramData%\ridctl\config.json` (system) and `%UserProfile%\.ridctl\config.json` (user overrides).
- Downloads should be from trusted sources (Fido/Microsoft); surface final URL to users.

## Run Notes & Checklist Discipline
After each session, create/update a Markdown note under `notes/` named `YYYY-MM-DD.md` using `docs/AGENT_NOTES_TEMPLATE.md`.
- Summarize what you did, why, commands executed, and any blockers.
- Update `docs/CHECKLIST.md` by ticking completed boxes (commit the change).
- If blocked, document the reason and proceed to the next unblocked checklist item.
- Keep commits small and reference the checklist item (e.g., "M4: vmrun clone apply path").

