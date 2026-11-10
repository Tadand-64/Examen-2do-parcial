#!/usr/bin/env python3
"""Version secuencial (lectura linea a linea) de la misma pregunta.

Uso: python3 secuencial.py /data/input/ventas_<matricula>.csv > salida.txt
Misma salida que el reducer: tienda \t ingreso_total \t num_registros \t ticket_promedio
"""
import sys
from collections import defaultdict

ruta = sys.argv[1]
centavos = defaultdict(int)
registros = defaultdict(int)
malformadas = 0

with open(ruta) as f:
    next(f)                          # encabezado
    for line in f:
        p = line.strip().split(",")
        if len(p) != 8 or not p[2]:
            malformadas += 1
            continue
        try:
            cantidad = int(p[5])
            precio = float(p[6])
        except ValueError:
            malformadas += 1
            continue
        centavos[p[2]] += round(cantidad * precio * 100)
        registros[p[2]] += 1

for tienda in sorted(centavos):
    c, n = centavos[tienda], registros[tienda]
    print(f"{tienda}\t{c / 100:.2f}\t{n}\t{c / n / 100:.2f}")

sys.stderr.write(f"Lineas malformadas: {malformadas}\n")
