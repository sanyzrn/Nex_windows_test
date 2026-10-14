param([string]$Destination = (Join-Path $env:RUNNER_TEMP 'InnoSetup'))
$ErrorActionPreference = 'Stop'
$installer = Join-Path $env:RUNNER_TEMP 'innosetup-6.7.3.exe'
$url = 'https://github.com/jrsoftware/issrc/releases/download/is-6_7_3/innosetup-6.7.3.exe'
# Digest published by the upstream GitHub release asset.
$expected = '9c73c3bae7ed48d44112a0f48e66742c00090bdb5bef71d9d3c056c66e97b732'
Invoke-WebRequest -Uri $url -OutFile $installer
if ((Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected) {
  throw 'Inno Setup installer checksum does not match the pinned upstream release.'
}
$process = Start-Process -FilePath $installer -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-', ('/DIR="' + $Destination + '"')) -WindowStyle Hidden -Wait -PassThru
if ($process.ExitCode -ne 0) { throw "Inno Setup installation failed: $($process.ExitCode)" }
$compiler = Join-Path $Destination 'ISCC.exe'
if (-not (Test-Path -LiteralPath $compiler)) { throw 'Inno Setup compiler was not installed.' }
if ($env:GITHUB_ENV) { "INNO_ISCC=$compiler" | Out-File -LiteralPath $env:GITHUB_ENV -Encoding utf8 -Append }
Write-Output 'Pinned Inno Setup 6.7.3 installed and verified.'
