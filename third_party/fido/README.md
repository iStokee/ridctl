# Fido integration for ridctl

Place the Fido PowerShell script here as `Get-WindowsIso.ps1` to enable automated ISO downloads.

Recommended source (verify before use):
- Raw GitHub: https://raw.githubusercontent.com/pbatard/Fido/master/powershell/fido.ps1

You can also install it via ridctl:

```pwsh
Import-Module ./src -Force
Install-RiDFido -PersistConfig -Apply
```

This downloads the script into this folder and saves its path to your user config under `Iso.FidoScriptPath`.

