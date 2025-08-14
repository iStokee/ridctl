# RiD Control

RiD is a PowerShell module and command‑line interface for managing
virtual machines used for development workflows.  It consolidates
existing guides for provisioning a VMware Workstation guest and
synchronising scripts between host and guest into a single tool.

This repository contains the source code for the module as well as
documentation, unit tests and build scripts. Some foundational
capabilities (virtualization checks, dry‑run/optional apply for
`vmrun` start/stop and shared folders) are implemented; the remaining
areas are scaffolded pending future milestones. Refer to `USAGE.md`
for a quick start guide.
