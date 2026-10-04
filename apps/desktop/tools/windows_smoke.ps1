param([string]$Release = (Join-Path $PSScriptRoot '../build/windows/x64/runner/Release'),
      [string]$Output = (Join-Path $env:TEMP 'nex-windows-smoke.json'))
$ErrorActionPreference = 'Stop'
$Release = (Resolve-Path -LiteralPath $Release).Path
$Output = [IO.Path]::GetFullPath($Output)
$exe = Join-Path $Release 'nex_desktop.exe'
foreach ($file in @('nex_desktop.exe', 'flutter_windows.dll', 'sqlite3.dll', 'file_selector_windows_plugin.dll', 'record_windows_plugin.dll', 'just_audio_windows_plugin.dll', 'data/flutter_assets', 'data/app.so', 'data/icudtl.dat')) {
    if (-not (Test-Path -LiteralPath (Join-Path $Release $file))) { throw "Missing bundle member: $file" }
}
if (Get-Process -Name nex_desktop -ErrorAction SilentlyContinue) { throw 'Close the existing Nex desktop instance before running smoke tests.' }
$probePath = [IO.Path]::ChangeExtension($Output, '.probe.json')
$secondPath = [IO.Path]::ChangeExtension($Output, '.second.json')
foreach ($file in @($probePath, $secondPath)) {
    if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file }
}
$primary = Start-Process -FilePath $exe -ArgumentList @('--native-smoke', ('"' + $probePath + '"')) -WorkingDirectory $Release -WindowStyle Hidden -PassThru
$deadline = [DateTime]::UtcNow.AddSeconds(15)
while (-not (Test-Path -LiteralPath $probePath)) {
    if ($primary.HasExited) { throw 'Probe exited before writing a report.' }
    if ([DateTime]::UtcNow -gt $deadline) { throw 'Probe did not finish in 15 seconds.' }
    Start-Sleep -Milliseconds 20
}
$second = Start-Process -FilePath $exe -ArgumentList @('--native-smoke', ('"' + $secondPath + '"')) -WorkingDirectory $Release -WindowStyle Hidden -PassThru
if (-not $second.WaitForExit(1500)) { throw 'Second instance did not return in 1.5 seconds.' }
$singleInstance = $second.ExitCode -eq 0 -and -not $primary.HasExited -and -not (Test-Path -LiteralPath $secondPath)
$exitWatch = [Diagnostics.Stopwatch]::StartNew()
if (-not $primary.WaitForExit(10000)) { throw 'Clean shutdown exceeded 10 seconds.' }
$exitWatch.Stop()
$result = Get-Content -LiteralPath $probePath -Raw | ConvertFrom-Json
$result | Add-Member singleInstance $singleInstance
$result | Add-Member exitCode $primary.ExitCode
$result | Add-Member shutdownWaitMs $exitWatch.ElapsedMilliseconds
$result | Add-Member fullBundle $true
if (-not ('NexWindowProbe' -as [type])) {
    Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class NexWindowProbe {
    private delegate bool EnumProc(IntPtr hwnd, IntPtr unused);
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumProc callback, IntPtr unused);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint processId);
    [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr hwnd);
    [DllImport("user32.dll")] private static extern int GetClassName(IntPtr hwnd, StringBuilder lpClassName, int nMaxCount);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hwnd, uint message, IntPtr wparam, IntPtr lparam);
    public static IntPtr VisibleWindow(uint processId) {
        IntPtr found = IntPtr.Zero;
        EnumWindows((hwnd, unused) => {
            uint owner; GetWindowThreadProcessId(hwnd, out owner);
            if (owner == processId && IsWindowVisible(hwnd)) {
                var sb = new StringBuilder(256);
                GetClassName(hwnd, sb, 256);
                if (sb.ToString() == "RIGHT_PANEL_WIN32_WINDOW") {
                    found = hwnd;
                    return false;
                }
            }
            return true;
        }, IntPtr.Zero);
        return found;
    }
}
'@
}
# This run opens the normal GUI/application-support library, without entering data.
$normal = Start-Process -FilePath $exe -WorkingDirectory $Release -WindowStyle Hidden -PassThru
$until = [DateTime]::UtcNow.AddSeconds(15)
$window = [IntPtr]::Zero
while ($window -eq [IntPtr]::Zero) {
    if ($normal.HasExited -or [DateTime]::UtcNow -gt $until) { throw 'Normal GUI did not render its first frame.' }
    $window = [NexWindowProbe]::VisibleWindow([uint32]$normal.Id)
    Start-Sleep -Milliseconds 20
}
# The runner shows its window only after Flutter's first-frame callback.
$result | Add-Member normalGuiFirstFrame $true
# Exercise the normal capture event route after the real hotkey was probed above.
[void][NexWindowProbe]::PostMessage($window, 0x0312, [IntPtr]1, [IntPtr]::Zero)
Start-Sleep -Milliseconds 500
$result | Add-Member normalGuiAliveAfterCapture (-not $normal.HasExited)
[void][NexWindowProbe]::PostMessage($window, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
if (-not $normal.WaitForExit(10000)) { throw 'Normal GUI failed to drain and close.' }
$result | Add-Member normalGuiExitCode $normal.ExitCode
$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Output -Encoding utf8
$result | ConvertTo-Json -Depth 8
if (-not ($result.tray -and $result.hotkey -and $result.hotkeyDelivered -and $result.captureOpened -and $result.displayChangeRefresh -and $result.startupToggle -and $result.startupRestored -and $singleInstance -and $primary.ExitCode -eq 0 -and $result.normalGuiAliveAfterCapture -and $result.normalGuiExitCode -eq 0)) { throw 'One or more native checks failed.' }
foreach ($position in $result.placements) { if (-not $position.edgeReveal) { throw "Edge reveal failed on monitor $($position.monitor) / $($position.edge)" } }
