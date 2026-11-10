# Corre todas las pruebas del examen y guarda cada salida en evidencias\*.txt (version Windows)
# Uso (desde la raiz del proyecto, con los contenedores arriba):
#   powershell -ExecutionPolicy Bypass -File scripts\evidencias.ps1
Set-Location (Split-Path $PSScriptRoot -Parent)
$E = "evidencias"
New-Item -ItemType Directory -Force $E | Out-Null
$MATRICULA = ((Get-Content .env | Where-Object { $_ -match '^MATRICULA=' }) -replace 'MATRICULA=', '').Trim()
$CSV = "/data/input/ventas_$MATRICULA.csv"
$API = "http://localhost:8000"

function Paso($t) { Write-Host "`n==== $t ====" -ForegroundColor Cyan }

function Guardar($archivo, [scriptblock]$bloque) {
    $salida = & $bloque 2>&1 | ForEach-Object { "$_" } |
        Where-Object { $_ -ne "System.Management.Automation.RemoteException" }
    $salida | Out-File -Encoding utf8 "$E\$archivo"
    $salida
}

function EsperarApi {
    for ($i = 0; $i -lt 30; $i++) {
        try { Invoke-RestMethod "$API/resultados" | Out-Null; return } catch { Start-Sleep 2 }
    }
}

Paso "A1. hadoop version"
Guardar "01_hadoop_version.txt" { docker compose exec -T hadoop hadoop version }

Paso "B. ssh localhost (sin contrasena)"
Guardar "02_ssh_localhost.txt" {
    docker compose exec -T -u hadoop hadoop ssh localhost 'echo Conectado a $(hostname) como $(whoami) sin contrasena'
}

Paso "B. ssh desde api hacia hadoop"
Guardar "03_ssh_api_a_hadoop.txt" {
    docker compose exec -T api ssh hadoop@hadoop 'echo Conectado a $(hostname) como $(whoami) desde api'
}

Paso "C1. Job MapReduce con time (tarda unos minutos)"
Guardar "04_job_mapreduce.txt" {
    docker compose exec -T -u hadoop hadoop bash -c "time bash /opt/mapreduce/run_job.sh"
}

Paso "C2. Script secuencial con time"
Guardar "05_secuencial.txt" {
    docker compose exec -T -u hadoop hadoop bash -c "time python3 /opt/mapreduce/secuencial.py $CSV > /data/output/secuencial.txt; cat /data/output/secuencial.txt"
}

Paso "C2. Coinciden los resultados?"
Guardar "06_comparacion.txt" {
    docker compose exec -T hadoop bash -c 'if diff <(sort /data/output/resultado/part-00000) <(sort /data/output/secuencial.txt); then echo OK: MapReduce y secuencial dan exactamente el mismo resultado; else echo DIFERENTES: revisar el diff; fi'
}

Paso "D. Cargar resultados a la base"
Guardar "07_carga.txt" { docker compose exec -T api python /scripts/cargar_resultados.py }

Paso "D. API"
Guardar "08_api.txt" {
    "GET /resultados"
    ConvertTo-Json -Compress -InputObject (Invoke-RestMethod "$API/resultados")
    "GET /resultados/T001"
    Invoke-RestMethod "$API/resultados/T001" | ConvertTo-Json -Compress
    "POST /resultados (T999)"
    $nuevo = @{ tienda = "T999"; ingreso_total = 1000; num_registros = 10; ticket_promedio = 100 } | ConvertTo-Json
    Invoke-RestMethod -Method Post -Uri "$API/resultados" -ContentType "application/json" -Body $nuevo | ConvertTo-Json -Compress
    "PUT /resultados/T999"
    $cambio = @{ ingreso_total = 2000; num_registros = 10; ticket_promedio = 200 } | ConvertTo-Json
    Invoke-RestMethod -Method Put -Uri "$API/resultados/T999" -ContentType "application/json" -Body $cambio | ConvertTo-Json -Compress
    "DELETE /resultados/T999"
    Invoke-RestMethod -Method Delete -Uri "$API/resultados/T999" | ConvertTo-Json -Compress
}

Paso "D. Persistencia: docker compose down / up"
Guardar "09_persistencia.txt" {
    "> docker compose down"
    docker compose down
    "> docker compose up -d"
    docker compose up -d
    EsperarApi
    "> GET /resultados/T001 (despues de reiniciar)"
    Invoke-RestMethod "$API/resultados/T001" | ConvertTo-Json -Compress
}

Write-Host "`nListo. Revisa la carpeta $E\" -ForegroundColor Green
