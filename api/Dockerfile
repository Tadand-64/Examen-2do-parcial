FROM python:3.12-slim

# Cliente SSH para conectarse al contenedor hadoop
RUN apt-get update && \
    apt-get install -y --no-install-recommends openssh-client && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /root/.ssh && \
    printf 'Host hadoop\n    User hadoop\n    IdentityFile /keys/id_api\n    StrictHostKeyChecking accept-new\n' > /root/.ssh/config && \
    chmod 700 /root/.ssh && chmod 600 /root/.ssh/config

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .

EXPOSE 8000
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
