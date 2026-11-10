#!/bin/bash
# Genera las llaves SSH al arrancar (no quedan dentro de la imagen) y levanta sshd.
set -e

SSH_DIR=/home/hadoop/.ssh
mkdir -p "$SSH_DIR"
touch "$SSH_DIR/authorized_keys"

# 1) Llave del usuario hadoop -> para "ssh localhost"
if [ ! -f "$SSH_DIR/id_ed25519" ]; then
    ssh-keygen -t ed25519 -N "" -f "$SSH_DIR/id_ed25519" -C "hadoop@localhost" -q
fi
grep -qF "$(cat "$SSH_DIR/id_ed25519.pub")" "$SSH_DIR/authorized_keys" || \
    cat "$SSH_DIR/id_ed25519.pub" >> "$SSH_DIR/authorized_keys"

# 2) Llave para el contenedor api (se comparte por el volumen /keys)
if [ ! -f /keys/id_api ]; then
    ssh-keygen -t ed25519 -N "" -f /keys/id_api -C "api@hadoop" -q
    chmod 600 /keys/id_api
fi
grep -qF "$(cat /keys/id_api.pub)" "$SSH_DIR/authorized_keys" || \
    cat /keys/id_api.pub >> "$SSH_DIR/authorized_keys"

# No preguntar "are you sure..." al conectarse a localhost
printf 'Host localhost\n    StrictHostKeyChecking accept-new\n' > "$SSH_DIR/config"

chown -R hadoop:hadoop "$SSH_DIR"
chmod 700 "$SSH_DIR"
chmod 600 "$SSH_DIR/authorized_keys" "$SSH_DIR/config"

chown hadoop:hadoop /data/output   # para que el job pueda escribir resultados
ssh-keygen -A          # llaves de host de sshd
echo "Hadoop listo. $(hadoop version | head -n1)"
exec /usr/sbin/sshd -D -e
