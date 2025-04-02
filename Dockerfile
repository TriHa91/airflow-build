FROM ubuntu:latest

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV AIRFLOW_HOME=/opt/airflow
ENV AIRFLOW__CORE__LOAD_EXAMPLES=False

# Install dependencies
RUN apt-get update && apt-get install -y \
    docker.io \
    python3 \
    python3-pip \
    python3-dev \
    python3.12-venv \
    curl \
    vim \
    ssh \
    nano \
    sudo \
    git \
    gcc \
    make \
    pkg-config \
    libmariadb-dev \
    libpq-dev \
    unixodbc-dev \
    netcat-openbsd \
    gosu \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR ${AIRFLOW_HOME}

# Create and activate virtual environment
RUN python3 -m venv ${AIRFLOW_HOME}/venv
ENV PATH="${AIRFLOW_HOME}/venv/bin:$PATH"

# Install Airflow
RUN pip install --upgrade pip setuptools wheel
RUN pip install --no-cache-dir \
    apache-airflow==2.10.5 \
    apache-airflow-providers-docker \
    apache-airflow-providers-postgres \
    apache-airflow-providers-mysql \
    apache-airflow-providers-trino \
    apache-airflow-providers-microsoft-mssql

# Create user
RUN useradd -ms /bin/bash rrkts_airflow && usermod -aG docker rrkts_airflow && newgrp docker
    
#RUN groupadd -g 103 docker && \
   # useradd -m -u 1001 -g docker -G docker rrkts_airflow

# Create necessary directories with correct ownership
RUN mkdir -p ${AIRFLOW_HOME}/dags ${AIRFLOW_HOME}/host_dags ${AIRFLOW_HOME}/logs ${AIRFLOW_HOME}/certs \
    && chown -R rrkts_airflow:rrkts_airflow ${AIRFLOW_HOME}

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh

# Set permissions
RUN chmod +x /entrypoint.sh && \
    chown -R rrkts_airflow:rrkts_airflow ${AIRFLOW_HOME}

# Expose HTTPS port
EXPOSE 7443

# Healthcheck for HTTPS
HEALTHCHECK --interval=30s --timeout=10s --retries=5 \
    CMD curl -kf https://localhost:7443/ --insecure || exit 1

# Use entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
