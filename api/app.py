"""API de resultados: ticket promedio por tienda (FastAPI + PostgreSQL).

Se conecta a la base por nombre de servicio (DB_HOST=db).
Los datos se cargan con scripts/cargar_resultados.py.
"""
import os
import time

import psycopg2
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(title="Examen P2 - Ticket promedio por tienda")


class Resultado(BaseModel):
    tienda: str
    ingreso_total: float
    num_registros: int
    ticket_promedio: float


class ResultadoUpdate(BaseModel):
    ingreso_total: float
    num_registros: int
    ticket_promedio: float


def conectar():
    return psycopg2.connect(
        host=os.getenv("DB_HOST", "db"),
        port=os.getenv("DB_PORT", "5432"),
        dbname=os.environ["POSTGRES_DB"],
        user=os.environ["POSTGRES_USER"],
        password=os.environ["POSTGRES_PASSWORD"],
    )


@app.on_event("startup")
def crear_tabla():
    for _ in range(20):  # reintenta mientras la base termina de arrancar
        try:
            with conectar() as con, con.cursor() as cur:
                cur.execute("""
                    CREATE TABLE IF NOT EXISTS resultados (
                        tienda          VARCHAR(10) PRIMARY KEY,
                        ingreso_total   NUMERIC(16,2) NOT NULL,
                        num_registros   INTEGER NOT NULL,
                        ticket_promedio NUMERIC(12,2) NOT NULL
                    )""")
            return
        except psycopg2.OperationalError:
            time.sleep(2)
    raise RuntimeError("No se pudo conectar a la base de datos")


def a_dict(r):
    return {"tienda": r[0], "ingreso_total": float(r[1]),
            "num_registros": r[2], "ticket_promedio": float(r[3])}


@app.get("/resultados")
def listar():
    with conectar() as con, con.cursor() as cur:
        cur.execute("SELECT * FROM resultados ORDER BY tienda")
        return [a_dict(r) for r in cur.fetchall()]


@app.get("/resultados/{tienda}")
def por_tienda(tienda: str):
    with conectar() as con, con.cursor() as cur:
        cur.execute("SELECT * FROM resultados WHERE tienda = %s", (tienda,))
        r = cur.fetchone()
    if not r:
        raise HTTPException(404, f"No hay resultados para la tienda {tienda}")
    return a_dict(r)


@app.post("/resultados", status_code=201)
def crear(r: Resultado):
    try:
        with conectar() as con, con.cursor() as cur:
            cur.execute("INSERT INTO resultados VALUES (%s, %s, %s, %s)",
                        (r.tienda, r.ingreso_total, r.num_registros, r.ticket_promedio))
    except psycopg2.errors.UniqueViolation:
        raise HTTPException(409, "Esa tienda ya existe")
    return r


@app.put("/resultados/{tienda}")
def actualizar(tienda: str, r: ResultadoUpdate):
    with conectar() as con, con.cursor() as cur:
        cur.execute("""UPDATE resultados
                       SET ingreso_total = %s, num_registros = %s, ticket_promedio = %s
                       WHERE tienda = %s""",
                    (r.ingreso_total, r.num_registros, r.ticket_promedio, tienda))
        if cur.rowcount == 0:
            raise HTTPException(404, f"No hay resultados para la tienda {tienda}")
    return {"tienda": tienda, **r.model_dump()}


@app.delete("/resultados/{tienda}")
def borrar(tienda: str):
    with conectar() as con, con.cursor() as cur:
        cur.execute("DELETE FROM resultados WHERE tienda = %s", (tienda,))
        if cur.rowcount == 0:
            raise HTTPException(404, f"No hay resultados para la tienda {tienda}")
    return {"borrada": tienda}
