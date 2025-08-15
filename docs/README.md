# RiD Control

RiD is a PowerShell module and command‑line interface for managing
virtual machines used for development workflows.  It consolidates
existing guides for provisioning a VMware Workstation guest and
synchronising scripts between host and guest into a single tool.

This repository contains the source code for the module as well as
documentation, unit tests and build scripts. Some foundational
capabilities (virtualization checks, native `-WhatIf/-Confirm` for
`vmrun` start/stop/snapshot/shared folders) are implemented; the remaining
areas are scaffolded pending future milestones. Refer to `USAGE.md`
for a quick start guide, including registering existing VMs by name and
using `-Name` with management commands for a better UX. The host menu includes an Options pane to configure defaults (download folder, ISO options, templates, shared folder, vmrun path), and a first‑run setup prompts for key values.

## Registered VMs

For a smoother experience, you can register existing VMs with friendly names and manage them from the menu:
- Register: `Register-RiDVM -Name <friendly> -VmxPath <path>`
- List: `Get-RiDVM` (or filter with `-Name`)
- Remove: `Unregister-RiDVM -Name <friendly>`

In `Show-RiDMenu` (host), choose `7) Registered VMs` to:
- See your registered list (or be prompted to register one if empty)
- Select an index to Start, Stop, or Snapshot
- Use `r` to register another or `u` to unregister
