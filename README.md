# Examen 2do parcial – Manejo Masivo de Datos

| | |
|---|---|
| **Alumno** | Andrés Tadeo Carmona Capula |
| **Matrícula** | 125052403 |
| **Pregunta asignada** (último dígito 3) | **Ticket promedio** (ingreso promedio por registro) **por tienda**, con ingreso = `cantidad × precio_unitario` |

## Estructura
```
├── README.md
├── .gitignore              # incluye *.csv y .env
├── .env.example
├── docker-compose.yml
├── generar_dataset.py
├── hadoop/
│   ├── Dockerfile          # Debian + OpenJDK 17 + Python 3 + Hadoop 3.3.6 (standalone) + OpenSSH
│   └── entrypoint.sh       # genera llaves SSH y arranca sshd
├── mapreduce/
│   ├── mapper.py
│   ├── reducer.py
│   ├── secuencial.py
│   └── run_job.sh          # comando de Hadoop Streaming
├── api/
│   ├── Dockerfile
│   ├── requirements.txt
│   └── app.py              # FastAPI: /resultados
├── scripts/
│   ├── cargar_resultados.py
│   └── evidencias.sh       # corre todas las pruebas y guarda logs
└── evidencias/
```

## Cómo levantarlo
```bash
git clone https://github.com/Tadand-64/Examen-2do-parcial.git
cd Examen-2do-parcial
python3 generar_dataset.py 125052403     # genera ventas_125052403.csv (NO se sube al repo)
cp .env.example .env                     # credenciales y matrícula
docker compose up -d --build
```
El CSV se monta como volumen de solo lectura en `/data/input`. Las carpetas `mapreduce/` y `scripts/` también se montan, así que un cambio en el mapper o el reducer no requiere reconstruir la imagen.

## Evidencias
Todas se generan con un solo script y quedan en `evidencias/`:
- Windows (PowerShell): `powershell -ExecutionPolicy Bypass -File scripts\evidencias.ps1`
- Linux / Git Bash: `bash scripts/evidencias.sh`
 También se pueden correr una por una:

| Evidencia | Comando | Archivo |
|---|---|---|
| `hadoop version` | `docker compose exec hadoop hadoop version` | `01_hadoop_version.txt` |
| `ssh localhost` sin contraseña | `docker compose exec -u hadoop hadoop ssh localhost` | `02_ssh_localhost.txt` |
| SSH de `api` a `hadoop` | `docker compose exec api ssh hadoop@hadoop` | `03_ssh_api_a_hadoop.txt` |
| Job MapReduce | `docker compose exec -u hadoop hadoop bash /opt/mapreduce/run_job.sh` | `04_job_mapreduce.txt` |
| Secuencial | `docker compose exec -u hadoop hadoop python3 /opt/mapreduce/secuencial.py /data/input/ventas_125052403.csv` | `05_secuencial.txt` |
| Comparación | `diff <(sort output/resultado/part-00000) <(sort output/secuencial.txt)` | `06_comparacion.txt` |
| Carga a la BD | `docker compose exec api python /scripts/cargar_resultados.py` | `07_carga.txt` |
| API | `curl localhost:8000/resultados` y `curl localhost:8000/resultados/T001` | `08_api.txt` |
| Persistencia | `docker compose down && docker compose up -d` y luego GET | `09_persistencia.txt` |

Documentación interactiva de la API: http://localhost:8000/docs

### Endpoints
| Método | Ruta | Qué hace |
|---|---|---|
| GET | `/resultados` | Todos los registros |
| GET | `/resultados/{tienda}` | Filtro por tienda (ej. `T001`) |
| POST | `/resultados` | Inserta una tienda |
| PUT | `/resultados/{tienda}` | Actualiza una tienda |
| DELETE | `/resultados/{tienda}` | Borra una tienda |

### Seguridad SSH
- El usuario `hadoop` no tiene contraseña y `PasswordAuthentication no` está activo: solo se entra con llave.
- Las llaves se generan con `ssh-keygen` al arrancar el contenedor (`entrypoint.sh`), así que no quedan dentro de la imagen ni en el repo.
- La llave pública del contenedor `api` se agrega a `authorized_keys`. La llave privada se comparte con `api` mediante el volumen `ssh_keys`, montado en solo lectura.

## C2. Comparativa de rendimiento

| Método | Tiempo (`real`) | ¿Mismo resultado? |
|---|---|---|
| Hadoop Streaming (standalone) | **2m 22.99s** | Sí, `diff` sin diferencias (34 tiendas) |
| Python secuencial | **0m 57.93s** | |

En este escenario el script secuencial fue unas 2.5 veces más rápido que Hadoop (58 s contra 2 min 23 s). El archivo pesa unos 400 MB y se procesa en una sola máquina, en modo standalone, donde Hadoop no reparte el trabajo entre nodos y solo agrega sobrecosto. Antes de procesar un solo registro, arranca la JVM y configura el job. Después parte la entrada en splits y, con Streaming, manda cada línea como texto por una tubería entre Java y un proceso Python aparte. Al terminar los mappers hace el *sort & shuffle*, que escribe a disco y ordena 5 millones de pares clave-valor antes de pasarlos al reducer. El script secuencial, en cambio, lee el archivo una vez y acumula en un diccionario en memoria (34 tiendas), sin ordenar ni serializar nada. MapReduce compensa cuando los datos no caben en una máquina y hay un clúster que procese los bloques en paralelo, cerca de donde están guardados.

## E. Teoría

**1. Modos de Hadoop.** En **standalone** (local) todo corre en un solo proceso Java, sin demonios y sobre el sistema de archivos local; sirve para probar y depurar jobs. En **pseudo-distribuido** cada demonio (NameNode, DataNode, ResourceManager, NodeManager) corre como un proceso separado, pero todos en la misma máquina. Ahí se usa HDFS con replicación 1, y los scripts `start-*.sh` necesitan `ssh localhost`. En **totalmente distribuido** los demonios se reparten en un clúster de varios nodos, con maestro y trabajadores, y HDFS replica los bloques entre máquinas. **HDFS se usa en pseudo-distribuido y en totalmente distribuido**, no en standalone.

**2. ¿Por qué volumen y no `COPY`?**
- El dataset pesa unos 400 MB. Copiarlo haría la imagen pesada y lenta de construir y de subir a un registry.
- Separa datos de código: puedes cambiar o regenerar el CSV sin reconstruir la imagen, y la misma imagen sirve para el dataset de cualquier matrícula.
- Con `:ro` el contenedor no puede modificar el original.
- Los datos no terminan dentro de una imagen que se podría publicar.

**3. `docker compose down` vs `down -v`.** `docker compose down` detiene y elimina los contenedores y la red, pero **conserva los volúmenes nombrados**. Por eso, al volver a hacer `up`, Postgres encuentra sus datos en `pgdata`. `docker compose down -v` además **borra los volúmenes** (`pgdata` y `ssh_keys`). La base arranca vacía, hay que volver a cargar los resultados, y las llaves SSH se regeneran.

**4. ¿Por qué MapReduce no siempre es más rápido con 400 MB?** MapReduce tiene un costo fijo alto: arrancar la JVM, planear el job, partir la entrada, serializar a texto (con Streaming además hay que pasar datos entre Java y Python) y hacer el *shuffle & sort* en disco. Con 400 MB en una sola máquina ese costo es mayor que el beneficio, porque no hay paralelismo real. Conviene cuando los datos son mucho más grandes de lo que cabe en la memoria o el disco de un equipo (decenas de GB a TB), cuando hay un clúster con varios nodos y los datos ya están en HDFS (localidad de datos), y cuando el job es lo bastante largo para que el costo de arranque sea despreciable y la tolerancia a fallos importe.

**5. `CMD` vs `ENTRYPOINT`, `COPY` vs `ADD`.**
- `ENTRYPOINT` define el ejecutable fijo del contenedor. Lo que pongas en `docker run imagen ...` se le pasa como argumentos, y solo se reemplaza con `--entrypoint`.
- `CMD` define el comando o los argumentos por defecto, y se reemplaza por completo si pasas otro comando al ejecutar. Juntos, `ENTRYPOINT` es el programa y `CMD` sus argumentos por defecto.
- `COPY` solo copia archivos del contexto de build a la imagen.
- `ADD` además descomprime automáticamente archivos `.tar` locales y puede descargar desde una URL. Se recomienda `COPY` salvo que necesites eso.
