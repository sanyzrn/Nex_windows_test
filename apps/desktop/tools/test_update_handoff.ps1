param(
    [string]$Release = (Join-Path $PSScriptRoot '../build/windows/x64/runner/Release'),
    [string]$InstallerDirectory = (Join-Path $PSScriptRoot '../build/installer/output')
)
$ErrorActionPreference = 'Stop'
$Release = (Resolve-Path -LiteralPath $Release).Path
$helper = Join-Path $Release nex_update.exe
$helperHash = (Get-FileHash -LiteralPath $helper -Algorithm SHA256).Hash.ToLowerInvariant()
& $helper --verify-update $helper $helperHash
if ($LASTEXITCODE -ne 0) { throw 'Native verifier rejected the exact executable hash.' }
& $helper --verify-update $helper ('0' * 64)
if ($LASTEXITCODE -eq 0) { throw 'Native verifier accepted an invalid hash.' }
$setup = @(Get-ChildItem -LiteralPath $InstallerDirectory -Filter 'Nex-Windows-Setup-*-x64.exe')
if ($setup.Count -ne 1) { throw 'Expected one installer.' }
$digest = (Get-FileHash -LiteralPath $setup[0].FullName -Algorithm SHA256).Hash.ToLowerInvariant()
$root = Join-Path $env:RUNNER_TEMP ('nex updater integration ' + [guid]::NewGuid().ToString('N'))
$app = Join-Path $root 'installed app فارسی'
$cache = Join-Path $root 'download cache آزمایش'
New-Item -ItemType Directory -Path $app, $cache | Out-Null
Copy-Item -Path (Join-Path $Release '*') -Destination $app -Recurse
$copiedHelper = Join-Path $cache nex_update.exe
Copy-Item -LiteralPath $helper -Destination $copiedHelper
$download = Join-Path $cache $setup[0].Name
Copy-Item -LiteralPath $setup[0].FullName -Destination $download
$target = Join-Path $app nex_desktop.exe
# Marker proves updates preserve System/saved locale rather than replaying the wizard.
$marker = Join-Path $app install-language.txt
'fa|preserve-this-marker' | Set-Content -LiteralPath $marker -Encoding ascii -NoNewline
$report = Join-Path $root probe.json
$parent = $null
$worker = $null
try {
    $parent = Start-Process -FilePath $target -ArgumentList @('--native-smoke', ('"' + $report + '"')) -WorkingDirectory $app -WindowStyle Hidden -PassThru
    $nonce = [guid]::NewGuid().ToString()
    $arguments = @('--apply-update', [string]$parent.Id, ('"' + $download + '"'), $digest, ('"' + $target + '"'), $nonce, 'english')
    $worker = Start-Process -FilePath $copiedHelper -ArgumentList $arguments -WorkingDirectory $cache -WindowStyle Hidden -PassThru
    $ready = $download + '.ready'
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    while (-not (Test-Path -LiteralPath $ready)) {
        if ($worker.HasExited) { throw "Update helper exited before handoff: $($worker.ExitCode)" }
        if ([DateTime]::UtcNow -gt $deadline) { throw 'Update handoff never became ready.' }
        Start-Sleep -Milliseconds 50
    }
    if ((Get-Content -LiteralPath $ready -Raw) -ne $nonce) { throw 'Handoff nonce mismatch.' }
    if (-not $parent.WaitForExit(15000) -or $parent.ExitCode -ne 0) { throw 'Parent did not close cleanly.' }
    if (-not $worker.WaitForExit(120000) -or $worker.ExitCode -ne 0) {
        $log = $download + '.log'
        if (Test-Path -LiteralPath $log) { Get-Content -LiteralPath $log -Tail 35 }
        throw 'Verified installer/relaunch handoff failed.'
    }
    if ((Get-Content -LiteralPath ($download + '.result') -Raw) -ne '0') { throw 'Installer did not succeed.' }
    if ((Get-Content -LiteralPath $marker -Raw) -ne 'fa|preserve-this-marker') { throw 'Update overwrote saved installation language.' }
    $expectedVersion = (Get-Item -LiteralPath $setup[0].FullName).VersionInfo.ProductVersion
    $actualVersion = (Get-Item -LiteralPath $target).VersionInfo.ProductVersion
    Write-Host "Installed target version: $actualVersion; installer: $expectedVersion"
    # The helper is no longer running. Stop the relaunched GUI through its
    # normal WM_CLOSE route and exercise the newly installed complete bundle.
    Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class NexUpdateClose {
  private delegate bool Callback(IntPtr hwnd, IntPtr unused);
  [DllImport("user32.dll")] private static extern bool EnumWindows(Callback fn, IntPtr unused);
  [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint owner);
  [DllImport("user32.dll")] private static extern bool PostMessage(IntPtr hwnd, uint msg, IntPtr w, IntPtr l);
  public static void Close(uint pid) {
    EnumWindows((hwnd, unused) => { uint owner; GetWindowThreadProcessId(hwnd, out owner); if (owner == pid) PostMessage(hwnd, 0x0010, IntPtr.Zero, IntPtr.Zero); return true; }, IntPtr.Zero);
  }
}
'@
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    do {
        $restarted = @(Get-Process -Name nex_desktop -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $target })
        if ($restarted.Count -gt 0) { break }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
    if ($restarted.Count -ne 1) { throw 'Updated Nex was not relaunched exactly once.' }
    # Wait for first-frame/window setup before posting the normal close event.
    Start-Sleep -Seconds 2
    [NexUpdateClose]::Close([uint32]$restarted[0].Id)
    if (-not $restarted[0].WaitForExit(10000)) { throw 'Updated GUI did not close cleanly.' }
    & (Join-Path $PSScriptRoot windows_smoke.ps1) -Release $app -Output (Join-Path $root installed-smoke.json)
    Write-Host 'PASS: verified download, native helper handoff, real installation, locale preservation, restart and installed-bundle smoke.'
} finally {
    if ($worker -and -not $worker.HasExited) { Stop-Process -Id $worker.Id -Force -ErrorAction SilentlyContinue }
    Get-Process -Name nex_desktop -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $target } | Stop-Process -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}
