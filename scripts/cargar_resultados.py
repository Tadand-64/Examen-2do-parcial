#!/usr/bin/env python3
"""Lee la salida del job (part-00000) y la inserta en la tabla `resultados`.

Se ejecuta dentro del contenedor api (ya tiene psycopg2 y las variables del .env):
    docker compose exec api python /scripts/cargar_resultados.py
"""
import os
import sys

import psycopg2

RUTA = sys.argv[1] if len(sys.argv) > 1 else "/data/output/resultado/part-00000"

if not os.path.exists(RUTA):
    sys.exit(f"No existe {RUTA}. Primero corre el job de Hadoop.")

con = psycopg2.connect(
    host=os.getenv("DB_HOST", "db"),
    port=os.getenv("DB_PORT", "5432"),
    dbname=os.environ["POSTGRES_DB"],
    user=os.environ["POSTGRES_USER"],
    password=os.environ["POSTGRES_PASSWORD"],
)

n = 0
with con, con.cursor() as cur, open(RUTA) as f:
    cur.execute("""
        CREATE TABLE IF NOT EXISTS resultados (
            tienda          VARCHAR(10) PRIMARY KEY,
            ingreso_total   NUMERIC(16,2) NOT NULL,
            num_registros   INTEGER NOT NULL,
            ticket_promedio NUMERIC(12,2) NOT NULL
        )""")
    for linea in f:
        tienda, total, registros, promedio = linea.strip().split("\t")
        cur.execute("""
            INSERT INTO resultados VALUES (%s, %s, %s, %s)
            ON CONFLICT (tienda) DO UPDATE SET
                ingreso_total   = EXCLUDED.ingreso_total,
                num_registros   = EXCLUDED.num_registros,
                ticket_promedio = EXCLUDED.ticket_promedio""",
            (tienda, total, registros, promedio))
        n += 1
con.close()
print(f"Registros cargados en 'resultados': {n}")
