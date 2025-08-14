<#
    Edits a VMware .vmx configuration file by setting or updating key/value pairs.
    In dry-run mode (default), prints intended changes. With -Apply, writes to disk.
#>
function Set-RiDVmxSettings {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)] [string]$VmxPath,
        [Parameter(Mandatory=$true)] [hashtable]$Settings,
        [Parameter()] [switch]$Apply
    )
    if (-not (Test-Path -Path $VmxPath)) { Write-Error "VMX not found: $VmxPath"; return 1 }
    $lines = Get-Content -Path $VmxPath -ErrorAction Stop
    $original = @($lines)
    foreach ($key in $Settings.Keys) {
        $value = $Settings[$key]
        $escaped = [regex]::Escape($key)
        $pattern = "^$escaped\s*=\s*\".*\"\s*$"
        $newLine = '{0} = "{1}"' -f $key, $value
        $idx = [Array]::FindIndex($lines, [Predicate[string]]{ param($l) $l -match $pattern })
        if ($idx -ge 0) { $lines[$idx] = $newLine } else { $lines += $newLine }
    }
    if (-not $Apply) {
        Write-Host '[vmx] Changes (dry-run):' -ForegroundColor DarkCyan
        $diff = Compare-Object -ReferenceObject $original -DifferenceObject $lines -IncludeEqual:$false
        foreach ($d in $diff) {
            $pref = if ($d.SideIndicator -eq '=>') { '+' } else { '-' }
            Write-Host ("  {0} {1}" -f $pref, $d.InputObject) -ForegroundColor DarkCyan
        }
        return 0
    }
    Set-Content -Path $VmxPath -Value $lines -Encoding ASCII
    return 0
}

