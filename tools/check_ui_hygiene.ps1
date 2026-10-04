# UI hygiene gate (WP1.2 / WP4): fails when app code bypasses the design
# system with raw Color(0x...) literals or hard-coded user-facing strings.
# Both must come from nex_ui tokens / the ARB files instead.
#
# Allowlist policy: an entry is only permitted for
#  - palette interpolation done from theme colours (no literal colour);
#  - technical strings that never reach the user (wire names, debug keys);
#  - generated files (lib/l10n/**, lib/core/app_meta.dart).
param(
  [Parameter(Mandatory = $true)][string]$LibDir
)

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..\apps\desktop')

$files = Get-ChildItem -LiteralPath $LibDir -Recurse -Filter *.dart |
  Where-Object {
    $p = $_.FullName -replace '\\', '/'
    # Generated localisations carry the strings by design.
    $p -notmatch '/lib/l10n/' -and
    # The single source of the version string.
    $p -notmatch '/lib/core/app_meta\.dart$'
  }

$colorHits = @()
$literalHits = @()

foreach ($f in $files) {
  $lines = Get-Content -LiteralPath $f.FullName
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line -match 'Color\(0x') {
      $colorHits += "$($f.FullName -replace '\\','/'):$($i + 1): $($line.Trim())"
    }
    # A string literal passed straight to Text() or a tooltip: the two paths
    # user-visible copy takes. ARB lookups never match this shape.
    if ($line -match "Text\(\s*'[ Hath]|Text\(\s*'[A-Z]" -or
        $line -match "tooltip:\s*'[A-Z]") {
      $literalHits += "$($f.FullName -replace '\\','/'):$($i + 1): $($line.Trim())"
    }
  }
}

if ($colorHits.Count -gt 0) {
  Write-Host "Colour literals found (use nex_ui tokens / ThemeData):"
  $colorHits | ForEach-Object { Write-Host "  $_" }
}
if ($literalHits.Count -gt 0) {
  Write-Host "Hard-coded user-facing strings found (use the ARB files):"
  $literalHits | ForEach-Object { Write-Host "  $_" }
}
if ($colorHits.Count -gt 0 -or $literalHits.Count -gt 0) {
  exit 1
}
Write-Host "UI hygiene: OK (no colour literals, no hard-coded UI strings)"
exit 0
