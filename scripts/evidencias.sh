#!/bin/bash
# Corre todas las pruebas del examen y guarda cada salida en evidencias/*.txt
# Uso (desde la raíz del proyecto, con los contenedores arriba):  bash scripts/evidencias.sh
cd "$(dirname "$0")/.."
source .env
E=evidencias
mkdir -p "$E"
CSV=/data/input/ventas_${MATRICULA}.csv

paso() { echo; echo "==== $1 ===="; }

esperar_api() {
    for _ in $(seq 1 30); do
        curl -s localhost:8000/resultados >/dev/null && return
        sleep 2
    done
}

paso "A1. hadoop version"
docker compose exec -T hadoop hadoop version 2>&1 | tee $E/01_hadoop_version.txt

paso "B. ssh localhost (sin contraseña)"
docker compose exec -T -u hadoop hadoop ssh localhost "echo Conectado a \$(hostname) como \$(whoami)" 2>&1 | tee $E/02_ssh_localhost.txt

paso "B. ssh desde api hacia hadoop"
docker compose exec -T api ssh hadoop@hadoop "echo Conectado a \$(hostname) como \$(whoami)" 2>&1 | tee $E/03_ssh_api_a_hadoop.txt

paso "C1. Job MapReduce (con time)"
docker compose exec -T -u hadoop hadoop bash -c "time bash /opt/mapreduce/run_job.sh" 2>&1 | tee $E/04_job_mapreduce.txt

paso "C2. Script secuencial (con time)"
docker compose exec -T -u hadoop hadoop bash -c \
  "time python3 /opt/mapreduce/secuencial.py $CSV > /data/output/secuencial.txt; cat /data/output/secuencial.txt" \
  2>&1 | tee $E/05_secuencial.txt

paso "C2. ¿Coinciden los resultados?"
{
  if diff <(sort output/resultado/part-00000) <(sort output/secuencial.txt); then
      echo "OK: MapReduce y secuencial dan exactamente el mismo resultado"
  else
      echo "DIFERENTES (ver diff arriba)"
  fi
} 2>&1 | tee $E/06_comparacion.txt

paso "D. Cargar resultados a la base"
docker compose exec -T api python /scripts/cargar_resultados.py 2>&1 | tee $E/07_carga.txt

paso "D. API"
{
  echo '$ GET /resultados';            curl -s localhost:8000/resultados; echo
  echo '$ GET /resultados/T001';       curl -s localhost:8000/resultados/T001; echo
  echo '$ POST /resultados (T999)';    curl -s -X POST localhost:8000/resultados -H "Content-Type: application/json" \
        -d '{"tienda":"T999","ingreso_total":1000,"num_registros":10,"ticket_promedio":100}'; echo
  echo '$ PUT /resultados/T999';       curl -s -X PUT localhost:8000/resultados/T999 -H "Content-Type: application/json" \
        -d '{"ingreso_total":2000,"num_registros":10,"ticket_promedio":200}'; echo
  echo '$ DELETE /resultados/T999';    curl -s -X DELETE localhost:8000/resultados/T999; echo
} 2>&1 | tee $E/08_api.txt

paso "D. Persistencia: docker compose down / up"
{
  echo '$ docker compose down';  docker compose down
  echo '$ docker compose up -d'; docker compose up -d
  esperar_api
  echo '$ GET /resultados/T001 (después de reiniciar)'; curl -s localhost:8000/resultados/T001; echo
} 2>&1 | tee $E/09_persistencia.txt

echo; echo "Listo. Revisa la carpeta $E/"
