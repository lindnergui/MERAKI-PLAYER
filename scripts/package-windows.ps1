$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path -Parent $PSScriptRoot
$bundle = Join-Path $projectDirectory 'build/windows/x64/runner/Release'
$outputDirectory = Join-Path $projectDirectory 'dist/windows'
$versionLine = Get-Content (Join-Path $projectDirectory 'pubspec.yaml') |
    Where-Object { $_ -match '^version:' }
if ($versionLine -notmatch '^version:\s*(\d+\.\d+\.\d+)\+') {
    throw 'Versão do aplicativo inválida.'
}
$appVersion = $Matches[1]

foreach ($relative in @('meraki.exe', 'flutter_windows.dll', 'rust_lib_meraki.dll',
                        'msvcp140.dll', 'vcruntime140.dll', 'data/app.so', 'data/icudtl.dat', 'data/flutter_assets')) {
    if (-not (Test-Path -LiteralPath (Join-Path $bundle $relative))) {
        throw "Arquivo obrigatório ausente no pacote: $relative"
    }
}
if (-not (Get-ChildItem -LiteralPath $bundle -Filter '*mpv*.dll')) {
    throw 'Biblioteca nativa de reprodução não foi incluída.'
}

New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
Copy-Item -LiteralPath (Join-Path $projectDirectory 'LICENSE') -Destination (Join-Path $bundle 'LICENSE.txt')
Compress-Archive -Path (Join-Path $bundle '*') -DestinationPath (Join-Path $outputDirectory 'meraki-windows-portable.zip') -Force

$compiler = Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6/ISCC.exe'
if (-not (Test-Path -LiteralPath $compiler)) {
    throw 'Instale o Inno Setup 6 para gerar o instalador EXE.'
}
& $compiler "/DAppVersion=$appVersion" "/DSourceDir=$bundle" "/DOutputDir=$outputDirectory" (Join-Path $projectDirectory 'packaging/windows/meraki.iss')
if ($LASTEXITCODE -ne 0) { throw 'Falha ao criar o instalador.' }

# No CI, confirma que o instalador completo funciona fora da pasta de build.
if ($env:GITHUB_ACTIONS -eq 'true') {
    $installDirectory = Join-Path $env:RUNNER_TEMP 'Meraki-teste-instalacao'
    $installer = Join-Path $outputDirectory 'meraki-windows-setup.exe'
    $installation = Start-Process -FilePath $installer -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', "/DIR=`"$installDirectory`"") -WindowStyle Hidden -Wait -PassThru
    if ($installation.ExitCode -ne 0) { throw "Falha na instalação: $($installation.ExitCode)" }
    $app = Start-Process -FilePath (Join-Path $installDirectory 'meraki.exe') -WorkingDirectory $installDirectory -WindowStyle Hidden -PassThru
    try {
        Start-Sleep -Seconds 10
        $app.Refresh()
        if ($app.HasExited) { throw "O aplicativo instalado encerrou inesperadamente: $($app.ExitCode)" }
    } finally {
        if (-not $app.HasExited) { Stop-Process -Id $app.Id }
        $uninstall = Start-Process -FilePath (Join-Path $installDirectory 'unins000.exe') -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART') -WindowStyle Hidden -Wait -PassThru
        if ($uninstall.ExitCode -ne 0) { throw 'Falha na desinstalação de teste.' }
    }
}
Get-ChildItem -LiteralPath $outputDirectory | Select-Object Name, Length
