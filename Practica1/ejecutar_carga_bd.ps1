$ErrorActionPreference = "Stop"

Write-Host "Verificando servicio SQL Server (SQLEXPRESS)..."
$service = Get-Service -Name 'MSSQL$SQLEXPRESS' -ErrorAction SilentlyContinue

if (-not $service) {
    throw "No se encontro el servicio MSSQL`$SQLEXPRESS. Instala SQL Server Express antes de ejecutar este script."
}

if ($service.Status -ne "Running") {
    Write-Host "El servicio esta detenido. Intentando iniciarlo..."
    Start-Service -Name 'MSSQL$SQLEXPRESS'
    Start-Sleep -Seconds 5
}

$service = Get-Service -Name 'MSSQL$SQLEXPRESS'
if ($service.Status -ne "Running") {
    throw "SQL Server (SQLEXPRESS) no esta en ejecucion. Abre Servicios como administrador e inicia SQL Server (SQLEXPRESS)."
}

Write-Host "Instalando/verificando dependencias Python..."
python -m pip install -r .\requirements.txt

Write-Host "Ejecutando notebook ETL y cargando VuelosDW..."
Push-Location .\etl
try {
    python -m jupyter nbconvert --to notebook --execute .\etl_vuelos.ipynb --output .\etl_vuelos_ejecutado.ipynb --ExecutePreprocessor.timeout=1200
}
finally {
    Pop-Location
}

Write-Host "Carga finalizada. La base VuelosDW debe estar disponible en localhost\SQLEXPRESS."
