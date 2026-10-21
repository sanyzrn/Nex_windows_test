param([string]$Release = (Join-Path $PSScriptRoot '../build/windows/x64/runner/Release'),
      [string]$Output = (Join-Path $env:TEMP 'nex-windows-smoke.json'))
$ErrorActionPreference = 'Stop'
$Release = (Resolve-Path -LiteralPath $Release).Path
$Output = [IO.Path]::GetFullPath($Output)
$exe = Join-Path $Release 'nex_desktop.exe'
foreach ($file in @('nex_desktop.exe', 'nex_update.exe', 'flutter_windows.dll', 'sqlite3.dll', 'file_selector_windows_plugin.dll', 'record_windows_plugin.dll', 'just_audio_windows_plugin.dll', 'data/flutter_assets', 'data/app.so', 'data/icudtl.dat')) {
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
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hwnd);
    [DllImport("user32.dll")] private static extern int GetClassName(IntPtr hwnd, StringBuilder lpClassName, int nMaxCount);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hwnd, uint message, IntPtr wparam, IntPtr lparam);
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int left, top, right, bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct Point { public int x, y; }
    [StructLayout(LayoutKind.Sequential)] public struct MonitorInfo { public uint cbSize; public Rect monitor, work; public uint flags; }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out Rect rect);
    [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr hwnd, int x, int y, int w, int h, bool repaint);
    [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr hwnd);
    [DllImport("user32.dll")] private static extern bool GetCursorPos(out Point point);
    [DllImport("user32.dll")] private static extern IntPtr MonitorFromPoint(Point point, uint flags);
    [DllImport("user32.dll")] private static extern bool GetMonitorInfo(IntPtr monitor, ref MonitorInfo info);
    public static Rect Corner(IntPtr hwnd) {
        Point cursor; GetCursorPos(out cursor);
        var info = new MonitorInfo(); info.cbSize = (uint)Marshal.SizeOf(info);
        GetMonitorInfo(MonitorFromPoint(cursor, 1), ref info);
        double scale = GetDpiForWindow(hwnd) / 96.0;
        int margin = (int)(12 * scale);
        int width = Math.Min((int)(460 * scale), info.work.right - info.work.left - 2 * margin);
        int height = Math.Min((int)(760 * scale), info.work.bottom - info.work.top - 2 * margin);
        return new Rect { left = info.work.right - margin - width, top = info.work.bottom - margin - height,
            right = info.work.right - margin, bottom = info.work.bottom - margin };
    }
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
# Isolated opt-in close/tray run: user preferences and notes are never changed.
$lifePath = [IO.Path]::ChangeExtension($Output, '.lifecycle.json')
if (Test-Path -LiteralPath $lifePath) { Remove-Item -LiteralPath $lifePath }
$life = Start-Process -FilePath $exe -ArgumentList @('--lifecycle-smoke', ('"' + $lifePath + '"')) -WorkingDirectory $Release -PassThru
function Wait-LifeWindow([bool]$Visible) {
    $deadline = [DateTime]::UtcNow.AddSeconds(10)
    do {
        if ($life.HasExited) { throw 'Tray lifecycle exited before explicit Quit.' }
        $found = [NexWindowProbe]::VisibleWindow([uint32]$life.Id)
        if (($found -ne [IntPtr]::Zero) -eq $Visible) { return $found }
        Start-Sleep -Milliseconds 20
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Lifecycle visibility did not become $Visible."
}
function Assert-Corner([IntPtr]$Hwnd) {
    $frame = New-Object NexWindowProbe+Rect
    [void][NexWindowProbe]::GetWindowRect($Hwnd, [ref]$frame)
    $expected = [NexWindowProbe]::Corner($Hwnd)
    foreach ($side in @('left','top','right','bottom')) {
        if ([Math]::Abs($frame.$side - $expected.$side) -gt 1) { throw "Tray restore missed compact corner ($side): $($frame.$side) / $($expected.$side)" }
    }
}
try {
    $hwnd = Wait-LifeWindow $true
    # A visible focus request must not reset a custom frame.
    [void][NexWindowProbe]::MoveWindow($hwnd, 40, 40, 600, 600, $true)
    $before = New-Object NexWindowProbe+Rect
    [void][NexWindowProbe]::GetWindowRect($hwnd, [ref]$before)
    [void][NexWindowProbe]::PostMessage($hwnd, 0x0111, [IntPtr]40001, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 400
    $after = New-Object NexWindowProbe+Rect
    [void][NexWindowProbe]::GetWindowRect($hwnd, [ref]$after)
    foreach ($side in @('left','top','right','bottom')) {
        if ($before.$side -ne $after.$side) { throw 'Merely focusing moved the visible window.' }
    }
    foreach ($route in @('menu','click','activation')) {
        [void][NexWindowProbe]::PostMessage($hwnd, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
        [void](Wait-LifeWindow $false)
        if ($route -eq 'menu') {
            [void][NexWindowProbe]::PostMessage($hwnd, 0x0111, [IntPtr]40001, [IntPtr]::Zero)
        } elseif ($route -eq 'click') {
            [void][NexWindowProbe]::PostMessage($hwnd, 0x8001, [IntPtr]::Zero, [IntPtr]0x0202)
        } else {
            # Same HWND message emitted by single-instance activation.
            [void][NexWindowProbe]::PostMessage($hwnd, 0x8005, [IntPtr]::Zero, [IntPtr]::Zero)
        }
        $hwnd = Wait-LifeWindow $true
        Assert-Corner $hwnd
    }
    [void][NexWindowProbe]::PostMessage($hwnd, 0x0111, [IntPtr]40005, [IntPtr]::Zero)
    if (-not $life.WaitForExit(10000)) { throw 'Tray Quit did not drain and exit.' }
    if ($life.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $lifePath)) { throw 'Tray Quit did not finish cleanly.' }
    $drain = Get-Content -Raw -LiteralPath $lifePath | ConvertFrom-Json
    if (-not $drain.drained) { throw 'Tray Quit did not flush the feature store.' }
    $result | Add-Member trayLifecycle @{ closeHides = $true; processAlive = $true; menuRestores = $true; clickRestores = $true; activationRestores = $true; compactCorner = $true; visibleFocusPreservesFrame = $true; quitExitCode = $life.ExitCode; drained = $true }
} finally {
    if (-not $life.HasExited) { Stop-Process -Id $life.Id -Force }
}

$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Output -Encoding utf8
$result | ConvertTo-Json -Depth 8
if (-not ($result.tray -and $result.hotkey -and $result.hotkeyDelivered -and $result.captureOpened -and $result.displayChangeRefresh -and $result.startupToggle -and $result.startupRestored -and $singleInstance -and $primary.ExitCode -eq 0 -and $result.normalGuiAliveAfterCapture -and $result.normalGuiExitCode -eq 0)) { throw 'One or more native checks failed.' }
foreach ($position in $result.placements) { if (-not $position.edgeReveal) { throw "Edge reveal failed on monitor $($position.monitor) / $($position.edge)" } }
