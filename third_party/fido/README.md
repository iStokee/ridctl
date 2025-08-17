# Fido integration for ridctl

Place the Fido PowerShell script here as `Fido.ps1` (canonical) to enable automated ISO downloads. A small wrapper `RiD-GetWindowsIso.ps1` is generated automatically to expose headless commands and list operations.

Recommended source (verify before use):
- Raw GitHub: https://raw.githubusercontent.com/pbatard/Fido/master/powershell/fido.ps1

You can also install it via ridctl:

```pwsh
Import-Module ./src -Force
Install-RiDFido -PersistConfig -Apply    # optional: -PinToCommit <sha>
```

This downloads `Fido.ps1` into this folder and saves its path to your user config under `Iso.FidoScriptPath`.

