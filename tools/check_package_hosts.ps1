param([string]$Root = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path -LiteralPath $Root).Path
$workflow = Get-Content -LiteralPath (Join-Path $Root '.github/workflows/desktop.yml') -Raw
if ($workflow -match 'flutter-io\.cn|PUB_HOSTED_URL|FLUTTER_STORAGE_BASE_URL') {
  throw 'Package mirror host or override found in the workflow. Use default pub.dev.'
}
$pubspec = Get-Content -LiteralPath (Join-Path $Root 'apps/desktop/pubspec.yaml') -Raw
if ($pubspec -match 'flutter-io\.cn') { throw 'Mirror host recorded in pubspec.yaml.' }
$readme = Get-Content -LiteralPath (Join-Path $Root 'README.md') -Raw
if ($readme -match 'PUB_HOSTED_URL\s*=') { throw 'README instructs a package mirror.' }
Write-Output 'Package hosts: OK'
