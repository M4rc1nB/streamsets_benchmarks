#!/bin/bash

set -e

sudo su ubuntu

cd /home/ubuntu/

# Get SQL CMD added to repo
curl https://packages.microsoft.com/keys/microsoft.asc | sudo tee /etc/apt/trusted.gpg.d/microsoft.asc
curl https://packages.microsoft.com/config/ubuntu/20.04/prod.list | sudo tee /etc/apt/sources.list.d/mssql-release.list

# install sql server tools
sudo apt update -y && ACCEPT_EULA=Y apt-get install -y mssql-tools unixodbc-dev
ln -s /opt/mssql-tools/bin/sqlcmd sqlcmd

# install and enable Docker
sudo apt install -y jq
sudo apt install -y docker.io
sudo usermod -a -G docker ubuntu
sudo apt install docker-compose -y
docker network create my-shared-network

# Format and mount the disk
sudo mkfs.ext4 -F /dev/disk/by-id/google-"${INITIALS_PREFIX}"-persistent-disk
sudo mkdir -p /mnt/data
sudo mount /dev/disk/by-id/google-"${INITIALS_PREFIX}"-persistent-disk /mnt/data
sudo chown -R ubuntu:ubuntu /mnt/data

#Create persistant folders for docker-compose deployments
mkdir -p /mnt/data/sqlserver/data
mkdir -p /mnt/data/sqlserver/logs
mkdir -p /mnt/data/sqlserver/secrets
mkdir -p /mnt/data/seeds
mkdir -p /mnt/data/postgres/data
mkdir -p /mnt/data/oracle


#Oracle prerequisites
docker login container-registry.oracle.com --username marcin@streamsets.com --password ${SOURCE_PASS}
sudo useradd -u 54321 oracle
sudo chown -R ubuntu:ubuntu /mnt/data/
sudo chown oracle:oracle /mnt/data/oracle/


cat <<'EOT' >> docker-compose.yml
version: '2.2'

networks:
    my-shared-network:
        external: true
services:
  sqlserver:
      image:  mcr.microsoft.com/azure-sql-edge
      networks:
        - my-shared-network
      hostname: ${INITIALS_PREFIX}-sqlserver
      ports:
        - "1433:1433"
      user: root
      environment:
        ACCEPT_EULA: 1
        MSSQL_SA_PASSWORD: ${SQLSERVER_DATABASE_PASS}
        MSSQL_PID: Developer
        MSSQL_USER: ${SQLSERVER_DATABASE_USER}
      volumes:
          - "/mnt/data/sqlserver/data:/var/opt/mssql/data"
          - "/mnt/data/sqlserver/log:/var/opt/mssql/log"
          - "/mnt/data/sqlserver/secrets:/var/opt/mssql/secrets"
          - "/mnt/data/seeds/:/mnt/seeds/"
      restart: unless-stopped

  zookeeper:
    image: confluentinc/cp-zookeeper:latest
    networks:
      - my-shared-network
    hostname: ${INITIALS_PREFIX}-zookeeper-01
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000
    ports:
      - 22181:2181
    restart: unless-stopped

  kafka:
    image: confluentinc/cp-kafka:latest
    networks:
      - my-shared-network
    hostname: ${INITIALS_PREFIX}-kafka
    depends_on:
      - zookeeper
    ports:
      - 29092:29092
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://${INITIALS_PREFIX}-kafka:9092,PLAINTEXT_HOST://${INITIALS_PREFIX}-sx-db-benchmarks:29092
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
      KAFKA_INTER_BROKER_LISTENER_NAME: PLAINTEXT
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
    restart: unless-stopped

  postgres:
     image: postgres:latest
     networks:
       - my-shared-network
     hostname: ${INITIALS_PREFIX}-postgres
     #restart: always
     environment:
       - POSTGRES_DB=postgres
       - POSTGRES_USER=${POSTGRES_DATABASE_USER}
       - POSTGRES_PASSWORD=${POSTGRES_DATABASE_PASS}
     logging:
       options:
          max-size: 10m
          max-file: "3"
     ports:
       - '5432:5432'
     volumes:
       - /mnt/data/postgres/data:/var/lib/postgresql/data
     restart: unless-stopped

  oracle:
    image: container-registry.oracle.com/database/express:latest
    networks:
     - my-shared-network
    container_name: oracle_db
    hostname: ${INITIALS_PREFIX}-oracle
    ports:
      - "1521:1521"
    environment:
      - ORACLE_ALLOW_REMOTE=true
      - ORACLE_SID=XE
      - ORACLE_PDB=ORCLPDB1
      - ORACLE_PWD=${ORACLE_DATABASE_PASS}
      - ENABLE_ARCHIVELOG=true
    volumes:
      - /mnt/data/oracle:/opt/oracle/oradata  
    restart: unless-stopped 
EOT

sudo docker-compose up -d 

# Get Database Seeds
database_name=${SQLSERVER_DATABASE_NAME}
backup_file=$database_name".bak"
backup_file_log=$database_name"_log"
attempts=0
max_attempts=30

# SQL Server DB Restore
if [ ! -f "/mnt/data/seeds/$backup_file" ]; then
    gsutil -m cp -r gs://sx-benchmarks/database-seeds/sqlserver/$backup_file /mnt/data/seeds/
fi

while [ $attempts -lt $max_attempts ]; do
    if [ "$(docker container inspect -f '{{.State.Status}}' ubuntu_sqlserver_1 )" = "running" ]; then
        ./sqlcmd -U SA -P ${SQLSERVER_DATABASE_PASS} -Q "RESTORE FilelistOnly from disk = N'/mnt/seeds/$backup_file' RESTORE DATABASE $database_name FROM DISK=N'/mnt/seeds/$backup_file' WITH MOVE '$database_name' TO '/var/opt/mssql/data/$database_name.mdf', MOVE '$backup_file_log' TO '/var/opt/mssql/data/$database_name.ldf';"

        break
    else
        echo "Container is not running, waiting for 60 seconds (Attempt $((attempts+1)) of $max_attempts)..."
        sleep 60
        attempts=$((attempts+1))
    fi
done

if [ $attempts -eq $max_attempts ]; then
    echo "Maximum number of attempts reached, the container is still not running."
fi 