#!/bin/bash
# Corre el job con Hadoop Streaming (modo standalone).
# Uso dentro del contenedor: bash /opt/mapreduce/run_job.sh
set -e
INPUT=$(ls /data/input/ventas_*.csv | head -n1)
OUTPUT=/data/output/resultado
SRC=/opt/mapreduce                   # mapper.py y reducer.py (montados como volumen)

rm -rf "$OUTPUT"                     # Hadoop falla si la carpeta de salida ya existe
cd /tmp                              # Streaming desempaca su jar aqui (/opt/mapreduce es de solo lectura)
hadoop jar $HADOOP_HOME/share/hadoop/tools/lib/hadoop-streaming-*.jar \
    -files $SRC/mapper.py,$SRC/reducer.py \
    -input "$INPUT" \
    -output "$OUTPUT" \
    -mapper "python3 $SRC/mapper.py" \
    -reducer "python3 $SRC/reducer.py"

echo "---- $OUTPUT/part-00000 (tienda, ingreso_total, registros, ticket_promedio) ----"
cat "$OUTPUT/part-00000"
