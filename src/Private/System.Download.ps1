<#
    Streaming downloader with progress and redirect resolution.
    Uses System.Net.Http.HttpClient to download large files reliably
    and display a Write-Progress bar. Returns the output file path
    on success, or $null on failure.
#>

function Invoke-RiDDownload {
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)][string]$Uri,
        [Parameter(Mandatory=$true)][string]$OutFile,
        [Parameter()][int]$BufferKB = 512,
        [Parameter()][int]$MinExpectedMB = 100
    )
    try {
        $useBits = $false
        if (-not ('System.Net.Http.HttpClientHandler' -as [type])) {
            try { Add-Type -AssemblyName 'System.Net.Http' } catch { $useBits = $true }
        }
        if ($useBits) { throw [System.NotSupportedException]::new('HttpClient unavailable, falling back to BITS') }

        $handler = New-Object System.Net.Http.HttpClientHandler
        $handler.AllowAutoRedirect = $true
        $client = New-Object System.Net.Http.HttpClient($handler)
        $client.Timeout = [TimeSpan]::FromMinutes(120)

        $req = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Get, $Uri)
        $resp = $client.SendAsync($req, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
        if (-not $resp.IsSuccessStatusCode) { Write-Warning ("Download request failed: {0}" -f $resp.StatusCode); return $null }

        $finalUri = $resp.RequestMessage.RequestUri.AbsoluteUri
        $total = if ($resp.Content.Headers.ContentLength) { [int64]$resp.Content.Headers.ContentLength } else { -1 }

        $dir = Split-Path -Path $OutFile -Parent
        # Guard against empty path (e.g., OutFile is just a filename)
        if ($dir -and -not [string]::IsNullOrWhiteSpace($dir)) {
            if (-not (Test-Path -LiteralPath $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }
        }
        $fs = [System.IO.File]::Open($OutFile, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        try {
            $stream = $resp.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
            $buffer = New-Object byte[] ($BufferKB * 1024)
            $totalRead = 0L
            $read = 0
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            do {
                $read = $stream.Read($buffer, 0, $buffer.Length)
                if ($read -le 0) { break }
                $fs.Write($buffer, 0, $read)
                $totalRead += $read
                if ($total -gt 0) {
                    $pct = [int](($totalRead * 100) / $total)
                    Write-Progress -Activity 'Downloading ISO' -Status ("{0:N1} MB / {1:N1} MB" -f ($totalRead/1MB), ($total/1MB)) -PercentComplete $pct
                } else {
                    Write-Progress -Activity 'Downloading ISO' -Status ("{0:N1} MB" -f ($totalRead/1MB)) -PercentComplete -1
                }
            } while ($true)
            Write-Progress -Activity 'Downloading ISO' -Completed
        } finally {
            $fs.Close()
        }

        if (Test-Path -LiteralPath $OutFile) {
            $size = (Get-Item -LiteralPath $OutFile).Length
            if ($total -gt 0 -and $size -lt [math]::Max($total * 0.9, 1)) {
                Write-Warning 'Downloaded size appears smaller than expected.'
            }
            if (($size / 1MB) -lt $MinExpectedMB) {
                Write-Warning ("Downloaded file is small ({0:N1} MB). This may not be a full ISO. Falling back." -f ($size/1MB))
                try { Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue } catch {}
                return $null
            }
            return $OutFile
        }
        return $null
    } catch {
        # Fallback to BITS on Windows PowerShell
        try {
            if (Get-Command -Name Start-BitsTransfer -ErrorAction SilentlyContinue) {
                Write-Host '[dl] Using BITS transfer fallback...' -ForegroundColor Yellow
                $dir = Split-Path -Path $OutFile -Parent
                if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
                Start-BitsTransfer -Source $Uri -Destination $OutFile -DisplayName 'RiD ISO Download' -Description 'Downloading ISO via BITS' -TransferType Download -ErrorAction Stop
                if (Test-Path -LiteralPath $OutFile) { return $OutFile }
            }
        } catch { Write-Warning ("BITS transfer failed: {0}" -f $_) }
        Write-Error $_
        return $null
    }
}
