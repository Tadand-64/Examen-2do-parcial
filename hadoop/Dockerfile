FROM debian:bookworm-slim

ARG HADOOP_VERSION=3.3.6

# ---- Java, Python 3, OpenSSH Server y utilerías ----
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        openjdk-17-jdk-headless python3 openssh-server openssh-client \
        wget ca-certificates procps && \
    rm -rf /var/lib/apt/lists/* && \
    ln -s "$(dirname "$(dirname "$(readlink -f "$(which javac)")")")" /usr/lib/jvm/java

# ---- Variables de entorno ----
ENV JAVA_HOME=/usr/lib/jvm/java
ENV HADOOP_HOME=/opt/hadoop
ENV HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop
ENV PATH=$PATH:$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin

# ---- Hadoop en modo standalone (configuración por defecto) ----
# Si dejas hadoop-3.4.1.tar.gz dentro de hadoop/ se usa ese archivo;
# si no, se descarga (primero del CDN de Apache y si falla del archivo histórico).
COPY entrypoint.sh hadoop-*.tar.g[z] /tmp/
RUN cd /tmp && \
    if [ ! -f hadoop-${HADOOP_VERSION}.tar.gz ]; then \
        wget -q https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz || \
        wget -q https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz; \
    fi && \
    tar -xzf hadoop-${HADOOP_VERSION}.tar.gz -C /opt && \
    mv /opt/hadoop-${HADOOP_VERSION} $HADOOP_HOME && \
    rm -f /tmp/hadoop-*.tar.gz && \
    echo "export JAVA_HOME=$JAVA_HOME" >> $HADOOP_CONF_DIR/hadoop-env.sh

# Las sesiones SSH no heredan el ENV de Docker: se lo pasamos por PAM y por profile
RUN echo "JAVA_HOME=$JAVA_HOME"     >> /etc/environment && \
    echo "HADOOP_HOME=$HADOOP_HOME" >> /etc/environment && \
    echo "PATH=$PATH"               >> /etc/environment && \
    printf 'export JAVA_HOME=%s\nexport HADOOP_HOME=%s\nexport PATH=$PATH:%s/bin:%s/bin:%s/sbin\n' \
        "$JAVA_HOME" "$HADOOP_HOME" "$JAVA_HOME" "$HADOOP_HOME" "$HADOOP_HOME" > /etc/profile.d/hadoop.sh

# ---- Usuario sin contraseña (solo acceso con llaves) ----
RUN useradd -m -s /bin/bash hadoop && \
    usermod -p '*' hadoop && \
    mkdir -p /run/sshd && \
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/'   /etc/ssh/sshd_config && \
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/'              /etc/ssh/sshd_config

# ---- Arranque (mapper/reducer se montan como volumen en /opt/mapreduce) ----
RUN mv /tmp/entrypoint.sh /entrypoint.sh && sed -i "s/\r$//" /entrypoint.sh && \
    chmod +x /entrypoint.sh && mkdir -p /data/input /data/output /opt/mapreduce

EXPOSE 22
ENTRYPOINT ["/entrypoint.sh"]