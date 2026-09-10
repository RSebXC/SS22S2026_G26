$ErrorActionPreference = 'Stop'

$mysqlHome = 'C:\Program Files\MySQL\MySQL Server 8.4'
$mysqld = Join-Path $mysqlHome 'bin\mysqld.exe'
$dataDir = Join-Path $PSScriptRoot 'data'

if (-not (Test-Path -LiteralPath $mysqld)) {
    throw "No se encontro MySQL Server en: $mysqlHome"
}

New-Item -ItemType Directory -Force -Path $dataDir | Out-Null

# Inicializa una sola vez el almacenamiento local de esta practica.
if (-not (Test-Path -LiteralPath (Join-Path $dataDir 'mysql'))) {
    & $mysqld "--initialize-insecure" "--basedir=$mysqlHome" "--datadir=$dataDir" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "No se pudo inicializar el almacenamiento de MySQL."
    }
}

$existing = Get-Process mysqld -ErrorAction SilentlyContinue
if (-not $existing) {
    $arguments = '--basedir="' + $mysqlHome + '" --datadir="' + $dataDir + '" --port=3306 --bind-address=127.0.0.1 --console'
    $startArguments = @('/c', 'start', '"MySQL84"', ('"' + $mysqld + '" ' + $arguments))
    Start-Process -FilePath 'cmd.exe' -ArgumentList $startArguments -WindowStyle Hidden | Out-Null
}

$mysqladmin = Join-Path $mysqlHome 'bin\mysqladmin.exe'
for ($attempt = 1; $attempt -le 30; $attempt++) {
    $oldErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $mysqladmin -h 127.0.0.1 -P 3306 -u root ping 2>$null | Out-Null
    $pingExitCode = $LASTEXITCODE
    $ErrorActionPreference = $oldErrorAction
    if ($pingExitCode -eq 0) {
        Write-Output 'MySQL esta disponible en 127.0.0.1:3306.'
        exit 0
    }
    Start-Sleep -Seconds 1
}

throw 'MySQL no respondio en el puerto 3306.'
