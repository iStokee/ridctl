# Quick Start

> **Note**
> This document describes the intended usage of the RiD module.  The
> current implementation is a scaffold and does not yet implement
> these features.

To install the module once it is published to the PowerShell gallery:

```powershell
Install-Module -Name ridctl -Scope CurrentUser
Import-Module ridctl
Show-RiDMenu
```

This will display an adaptive menu with options to create a new VM,
check virtualization readiness, provision shared folders and
synchronise scripts.  Until those commands are implemented the
module will display placeholder messages.