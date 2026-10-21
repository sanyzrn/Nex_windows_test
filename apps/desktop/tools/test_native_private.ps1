$ErrorActionPreference = 'Stop'
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$installation = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $installation) { throw 'MSVC installation not found.' }
$developer = Join-Path $installation 'Common7/Tools/VsDevCmd.bat'
$temporary = Join-Path $env:RUNNER_TEMP ('nex-native-private-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temporary | Out-Null
$test = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../test/native_private_test.cpp'))
$source = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../windows/runner/native_private.cpp'))
$executable = Join-Path $temporary 'native_private_test.exe'
try {
    Push-Location $temporary
    try {
        $compile = 'call "' + $developer + '" -no_logo -arch=x64 && cl /nologo /std:c++17 /EHsc /W4 "' + $test + '" "' + $source + '" /Fe:"' + $executable + '" /link user32.lib ole32.lib windowsapp.lib'
        & cmd.exe /d /s /c $compile
        if ($LASTEXITCODE -ne 0) { throw 'Native private clipboard test did not compile.' }
        & $executable
        if ($LASTEXITCODE -ne 0) { throw 'Native private clipboard regression failed.' }
    } finally { Pop-Location }
} finally { Remove-Item -LiteralPath $temporary -Recurse -Force }
