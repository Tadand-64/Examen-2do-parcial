#!/usr/bin/env python3
"""Mapper - Ticket promedio por tienda.

Entrada : id,fecha_hora,tienda,categoria,producto,cantidad,precio_unitario,metodo_pago
Salida  : tienda \t ingreso_en_centavos

El ingreso se maneja en centavos (entero) para que la suma sea exacta y
coincida al centavo con el script secuencial.
"""
import sys


def malformada():
    # Contador de Hadoop Streaming: aparece en el resumen del job
    sys.stderr.write("reporter:counter:Ventas,LineasMalformadas,1\n")


for line in sys.stdin:
    p = line.strip().split(",")
    if p[0] == "id":                 # encabezado del CSV
        continue
    if len(p) != 8 or not p[2]:
        malformada()
        continue
    try:
        cantidad = int(p[5])
        precio = float(p[6])
    except ValueError:
        malformada()
        continue
    print(f"{p[2]}\t{round(cantidad * precio * 100)}")
