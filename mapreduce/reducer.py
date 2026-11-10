#!/usr/bin/env python3
"""Reducer - Ticket promedio por tienda.

Recibe las lineas ya ordenadas por tienda (Hadoop hace el sort/shuffle).
Salida: tienda \t ingreso_total \t num_registros \t ticket_promedio
"""
import sys

actual = None
centavos = 0
n = 0


def emitir():
    print(f"{actual}\t{centavos / 100:.2f}\t{n}\t{centavos / n / 100:.2f}")


for line in sys.stdin:
    try:
        tienda, valor = line.rstrip("\n").split("\t")
        valor = int(valor)
    except ValueError:
        continue                     # linea rara: se ignora sin tirar el job
    if tienda != actual:
        if actual is not None:
            emitir()
        actual, centavos, n = tienda, 0, 0
    centavos += valor
    n += 1

if actual is not None:
    emitir()
