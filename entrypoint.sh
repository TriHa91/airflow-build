#!/usr/bin/env bash
set -e

#Grant permissions for mounted volumes - this runs as root before switching user
if [ "$(id -u)" = "0" ]; then
  echo "Setting correct permissions as root..."

  # Set permissions for the host dags directory
  chown -R rrkts_airflow:rrkts_airflow ${AIRFLOW_HOME}/host_dags
  chmod -R 755 ${AIRFLOW_HOME}/host_dags

  # Set permissions for other directories
  chown -R rrkts_airflow:rrkts_airflow ${AIRFLOW_HOME}/logs
  chown -R rrkts_airflow:rrkts_airflow ${AIRFLOW_HOME}/certs
  #chown -R rrkts_airflow:rrkts_airflow /var/run/docker.sock

  # Switch to rrkts_airflow user if we're running as root
  echo "Switching to rrkts_airflow user..."
  exec gosu rrkts_airflow "$0" "$@"
  exit 0
fi

# From this point, we should be running as rrkts_airflow
echo "Running as $(id -un) with UID $(id -u)"

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
while ! nc -z postgres_airflow 5432; do
  sleep 1
done
echo "PostgreSQL is ready!"

# Initialize Airflow database
echo "Initializing the Airflow database..."
airflow db init

# Upgrade the database
echo "Upgrading Airflow database..."
airflow db upgrade

# Create admin user if it doesn't exist
echo "Creating admin user..."
airflow users create \
    --username rrkts \
    --firstname FIRST_NAME \
    --lastname LAST_NAME \
    --role Admin \
    --email admin@example.com \
    --password rrkts \
    || echo "User already exists"

# Force rescan of DAGs directory before starting services
echo "Scanning for DAGs in host_dags directory..."
ls -la ${AIRFLOW_HOME}/host_dags || echo "Warning: host_dags directory may be empty"
airflow dags list

# Start the requested Airflow component
echo "Starting $1..."
if [ "$1" = "webserver" ]; then
    # Start webserver with SSL certificates
    exec airflow webserver \
        --port 7443 \
        --ssl-cert /opt/airflow/certs/cert.pem \
        --ssl-key /opt/airflow/certs/key.pem
else
    exec airflow "$@"
fi
