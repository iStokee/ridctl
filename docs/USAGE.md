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

## Virtualization Readiness

Use `Test-RiDVirtualization [-Detailed]` on the host to verify that VMware Workstation can run VMs:

- Checks: CPU VT support and enabled state; Hyper-V, Virtual Machine Platform, Windows Hypervisor Platform; Hyper-V hypervisor active; hypervisor present now; Windows Sandbox; Core Isolation/Memory Integrity (HVCI); Device Guard/VBS; WSL (informational).
- Exit codes: 0 = Ready; 1 = Conflicted (features enabled that may block VMware); 2 = Not ready (CPU/BIOS).
- Detailed view prints conflicts (or “None”), any reasons for “Not Ready,” and raw values for transparency.
- Next steps: A single line summarizes actions to disable conflicts (e.g., disable Hyper-V/Platform features, set `bcdedit /set hypervisorlaunchtype off`, turn off Memory Integrity); most changes require a reboot to take effect.

## ISO Helper (Automated via Fido)

`Open-RiDIsoHelper` supports a Guided path (opens Microsoft’s download page) and an Automated path that integrates with the Fido script to obtain a direct ISO URL.

- Place the Fido script at `third_party\fido\Get-WindowsIso.ps1` or set `Iso.FidoScriptPath` in your config.
- Optionally set `Iso.DefaultDownloadDir` to suggest a download directory.
- The Automated path launches Fido in a new PowerShell window; follow the prompts, download the ISO, then select it in the file picker to return the path to callers.
  - Optional: choose “Try non-interactive” to attempt passing your version/language/destination to Fido. This depends on the Fido script variant; if unsupported, it falls back to interactive and you’ll be prompted as usual.

Install Fido via ridctl:

```pwsh
Import-Module ./src -Force
Install-RiDFido -PersistConfig -Apply
```

Example config:

```pwsh
$cfg = Get-RiDConfig
$cfg.Iso = @{
  FidoScriptPath = 'D:\tools\fido\Get-WindowsIso.ps1'
  DefaultDownloadDir = 'D:\ISOs'
}
Set-RiDConfig $cfg
```

Advanced (non-interactive)

ridctl uses Fido's command-line mode and tries to auto-download the ISO when you choose non-interactive:

- Defaults: Win = "Windows 11"/"Windows 10" (from your choice), Rel = 23H2 (Win11) / 22H2 (Win10), Ed = Pro, Arch = x64, Lang = your selection.
- You can set overrides in config (used for future runs):

```pwsh
$cfg = Get-RiDConfig
if (-not $cfg.Iso) { $cfg.Iso = @{} }
$cfg.Iso.Release = '23H2'   # or another release code
$cfg.Iso.Edition = 'Pro'    # e.g., Home, Pro, Education
$cfg.Iso.Arch    = 'x64'    # x64, x86, arm64
Set-RiDConfig $cfg
```

ridctl captures Fido's `-GetUrl` output, downloads to your destination, and returns the ISO path. If it can't obtain a URL, it falls back to the interactive flow.
## About VMX Paths

- A `.vmx` file is the VMware Workstation VM configuration file, usually located under your VM folder: `C:\VMs\MyVM\MyVM.vmx`.
- PowerShell does not treat backslashes as escapes — you do not need to double them. Use a normal Windows path.
- If the path contains spaces, wrap it in quotes.
- Examples:
  - `'C:\VMs\MyVM\MyVM.vmx'`
  - `"C:\VMs\My VM With Spaces\My VM With Spaces.vmx"`
- For clone operations, provide the destination folder. For management commands (start/stop/snapshot/share repair), provide the existing `.vmx` path.
