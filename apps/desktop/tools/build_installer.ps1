param(
  [string]$Release = (Join-Path $PSScriptRoot '../build/windows/x64/runner/Release'),
  [string]$ISCC = 'ISCC.exe',
  [string]$VCRuntime,
  [string]$Output = (Join-Path $PSScriptRoot '../build/installer/output')
)
$ErrorActionPreference = 'Stop'
$appRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$Release = (Resolve-Path -LiteralPath $Release).Path
foreach ($name in @('nex_desktop.exe', 'flutter_windows.dll', 'sqlite3.dll', 'file_selector_windows_plugin.dll', 'record_windows_plugin.dll', 'just_audio_windows_plugin.dll', 'sqlite3_flutter_libs_plugin.dll', 'data/app.so', 'data/icudtl.dat', 'data/flutter_assets')) {
  if (-not (Test-Path -LiteralPath (Join-Path $Release $name))) { throw "Missing Release member: $name" }
}
if (-not $VCRuntime) {
  $candidates = @(Get-ChildItem -Path 'C:\Program Files\Microsoft Visual Studio\*\*\VC\Redist\MSVC\*\x64\Microsoft.VC*.CRT', 'C:\Program Files (x86)\Microsoft Visual Studio\*\*\VC\Redist\MSVC\*\x64\Microsoft.VC*.CRT' -Directory -ErrorAction SilentlyContinue)
  $selected = $candidates | Sort-Object { [version]$_.Parent.Parent.Name } -Descending | Select-Object -First 1
  if (-not $selected) { throw 'Pass -VCRuntime with a licensed Visual Studio x64 redistributable CRT directory.' }
  $VCRuntime = $selected.FullName
}
$VCRuntime = (Resolve-Path -LiteralPath $VCRuntime).Path
foreach ($name in @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {
  if (-not (Test-Path -LiteralPath (Join-Path $VCRuntime $name))) { throw "Missing x64 VC runtime: $name" }
}
$payload = [IO.Path]::GetFullPath((Join-Path $appRoot 'build/installer/payload'))
$allowedBuild = [IO.Path]::GetFullPath((Join-Path $appRoot 'build')) + [IO.Path]::DirectorySeparatorChar
if (-not $payload.StartsWith($allowedBuild, [StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid staging path.' }
if (Test-Path -LiteralPath $payload) { Remove-Item -LiteralPath $payload -Recurse -Force }
New-Item -ItemType Directory -Path $payload -Force | Out-Null
Get-ChildItem -LiteralPath $Release -Force | Copy-Item -Destination $payload -Recurse -Force
Get-ChildItem -LiteralPath $VCRuntime -Filter '*.dll' | Copy-Item -Destination $payload -Force
Copy-Item -LiteralPath (Join-Path $appRoot 'THIRD_PARTY_NOTICES.md'), (Join-Path $appRoot 'LICENSE') -Destination $payload
New-Item -ItemType Directory -Path $Output -Force | Out-Null
$Output = (Resolve-Path -LiteralPath $Output).Path
$manifest = @(Get-ChildItem -LiteralPath $payload -File -Recurse | Sort-Object FullName | ForEach-Object {
  [pscustomobject]@{ path = $_.FullName.Substring($payload.Length + 1).Replace('\', '/'); sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant(); bytes = $_.Length }
})
$manifest | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $appRoot 'build/installer/payload-manifest.json') -Encoding utf8
& $ISCC ('/O' + $Output) (Join-Path $appRoot 'installer/nex.iss')
if ($LASTEXITCODE -ne 0) { throw "Inno compilation failed with exit $LASTEXITCODE" }
$setupPath = Join-Path $Output 'Nex-Windows-Setup-1.92.1.4-x64.exe'
Get-Item -LiteralPath $setupPath | Select-Object FullName, Length
Get-FileHash -LiteralPath $setupPath -Algorithm SHA256
