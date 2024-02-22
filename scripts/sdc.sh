#!/bin/bash

set -e

sudo apt update -y

# install and enable Docker
sudo apt install -y jq
sudo apt install -y docker.io
sudo usermod -a -G docker ubuntu
sudo apt install docker-compose -y
sudo apt install python3-pip -y
pip3 install streamsets
pip3 install --upgrade requests

docker network create my-shared-network
cd /home/ubuntu/

cat <<'EOT' > docker-compose.yml
version: '2.2'
networks:
    my-shared-network:
        external: true
services:
  sdc:
    image: streamsets/datacollector:5.9.1
    hostname: ${SDC_HOSTNAME}
    ports:
      - "18630:18630"
    environment:
      STREAMSETS_DEPLOYMENT_SCH_URL: ${PLATFORM_URL}
      STREAMSETS_DEPLOYMENT_ID: ${DEPLOYMENT_ID}
      STREAMSETS_DEPLOYMENT_TOKEN: ${DEPLOYMENT_TOKEN}
      ENGINE_SHUTDOWN_TIMEOUT: 10
    restart: unless-stopped
EOT

sudo docker-compose up -d

cat <<'EOT' > sx_conn_manager_cli.py
import sys
import time
import argparse
import logging
from streamsets.sdk import ControlHub

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def connect_to_control_hub(cred_id, token):
    return ControlHub(credential_id=cred_id, token=token)

import time

def select_engine(control_hub, hostname, threshold_time_sec=120, max_attempts=10, sleep_time=60):
    for attempt in range(max_attempts):
        engines = control_hub.engines.get_all()
        logger.info("List of Engines with Last Reported Time:")
        for engine in engines:
            last_reported_time_seconds = engine.last_reported_time / 1000
            last_reported_human_readable = time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(last_reported_time_seconds))
            logger.info("Engine ID: %s, Last Reported Time: %s", engine.id, last_reported_human_readable)

        current_time_seconds = time.time()
        for engine in engines:
            last_reported_time_seconds = engine.last_reported_time / 1000
            if (current_time_seconds - last_reported_time_seconds) <= threshold_time_sec and engine.engine_url == hostname:
                logger.info("Selected Engine:")
                logger.info("Engine ID: %s", engine.id)
                logger.info("Engine URL: %s", engine.engine_url)
                logger.info("Last Reported Time: %s", time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(last_reported_time_seconds)))
                return engine  # Return the selected engine
        
        logger.info("No engine found matching the criteria in attempt %s.", attempt + 1)
        if attempt < max_attempts - 1:
            logger.info("Waiting for a minute before next attempt...")
            time.sleep(sleep_time)
        else:
            logger.info("All attempts exhausted. Exiting loop.")
            return None  # Return None if no engine found.

def create_connection(control_hub, sch_connection_name, selected_engine, database_user, database_pass, connection_string, tags=['gcp', 'terraform']):
    if selected_engine is None:
        logger.error("Cannot create connection without a selected engine.")
        return
    
    logger.info("Building new connection:")
    connection_builder = control_hub.get_connection_builder()
    new_conn = connection_builder.build(title=sch_connection_name,
                                        connection_type='STREAMSETS_JDBC',
                                        authoring_data_collector=selected_engine,
                                        tags=tags)
    new_conn.connection_definition.configuration['connectionString'] = connection_string
    new_conn.connection_definition.configuration['username'] = database_user
    new_conn.connection_definition.configuration['password'] = database_pass
    logger.info("Adding new connection to SCH:")
    control_hub.add_connection(new_conn)

def update_connection(control_hub, sch_connection_name, database_user, database_pass, connection_string):
    existing_connections = [conn for conn in control_hub.connections if conn.name == sch_connection_name]

    if existing_connections:
        logger.info("Connections already exist with name: %s", sch_connection_name)
        for conn in existing_connections:
            conn.connection_definition.configuration['connectionString'] = connection_string
            conn.connection_definition.configuration['username'] = database_user
            conn.connection_definition.configuration['password'] = database_pass
            control_hub.update_connection(conn)
    else:
        logger.info("No connections found with name: %s", sch_connection_name)
        
def delete_connection(control_hub, connection):
    control_hub.delete_connection(connection)
    logger.info("Deleted connection with ID: %s", connection)  
    
def delete_pipeline(control_hub, pipeline):
    control_hub.delete_pipeline(pipeline)
    logger.info("Deleted pipeline with ID: %s", pipeline)           

def start_logic(sch_connection_name, control_hub, database_user, database_pass, connection_string, hostname):
    existing_connections = [conn for conn in control_hub.connections if conn.name == sch_connection_name]
    
    if existing_connections:
        update_connection(control_hub, sch_connection_name, database_user, database_pass, connection_string)
    else:
        selected_engine = select_engine(control_hub, hostname)
        create_connection(control_hub, sch_connection_name, selected_engine, database_user, database_pass, connection_string)
        create_pipeline(control_hub, sch_connection_name, selected_engine)

def parse_arguments():
    parser = argparse.ArgumentParser(description="Script to start or stop a connection")
    parser.add_argument('action', choices=['start', 'stop'], help='Action to perform (start or stop)')
    parser.add_argument('--cred_id', help='Credential ID')
    parser.add_argument('--token', help='Token')
    parser.add_argument('--sch_connection_name', help='Connection name')
    parser.add_argument('--database_user', help='Database user')
    parser.add_argument('--database_pass', help='Database password')
    parser.add_argument('--connection_string', help='Connection string')
    parser.add_argument('--hostname', help='Hostname')
    return parser.parse_args()

def create_pipeline(control_hub, sch_connection_name, selected_engine):
    
    pipeline_builder = control_hub.get_pipeline_builder(engine_type='data_collector',engine_id=selected_engine.id)
    
    # Create Pipeline
    pipeline_title = sch_connection_name
    pipeline = pipeline_builder.build(pipeline_title)
    connection = control_hub.connections.get(name=sch_connection_name)
    
    # Adding JDBC Multitable Consumer stage
    jdbc_multitable_consumer = pipeline_builder.add_stage('JDBC Multitable Consumer')
    
    # Adding connection
    jdbc_multitable_consumer.connection = connection.id
    
    # Table and jdbc configuration
    jdbc_multitable_consumer.set_attributes(
    max_batch_size_in_records=1000,
    maximum_number_of_tables=-1,
    table_configs=[{
        'schema': "dbo",
        'isTablePatternListProvided': False,
        'tablePattern': 'Dim%',
        'tablePatternList': [],
        'overrideDefaultOffsetColumns': False,
        'offsetColumns': [],
        'offsetColumnToInitialOffsetValue': [],
        'offsetColumnToLastOffsetValue': [],
        'enableNonIncremental': True,
        'partitioningMode': 'DISABLED',
        'partitionSize': '1000000',
        'maxNumActivePartitions': -1
    }]
    )
    
    # Adding Trash stage
    trash_stage = pipeline_builder.add_stage('Trash')

    # Connecting JDBC Multitable Consumer to Trash stage
    jdbc_multitable_consumer >> trash_stage
    
    # Compile pipline
    pipeline = pipeline_builder.build(sch_connection_name)
    
    # Save the Pipeline
    control_hub.publish_pipeline(pipeline, commit_message='Terraform Automation')
    logger.info("Pipeline '%s' created successfully.", pipeline_title)
    
def main():
    args = parse_arguments()

    if not all(vars(args).values()):
        logger.error("Error: All parameters are required.")
        sys.exit(1)

    action = args.action
    cred_id = args.cred_id
    token = args.token
    sch_connection_name = args.sch_connection_name
    database_user = args.database_user
    database_pass = args.database_pass
    connection_string = args.connection_string
    hostname = args.hostname
    
    control_hub = connect_to_control_hub(cred_id, token)
    
    if action == 'start':
        start_logic(sch_connection_name, control_hub, database_user, database_pass, connection_string, hostname)
    elif action == 'stop':
        
        existing_pipelines = [pipe for pipe in control_hub.pipelines if pipe.name == sch_connection_name]
        
        if existing_pipelines:
            for pipe in existing_pipelines:
                delete_pipeline(control_hub, pipe)
                break
        else:
            logger.info("No pipeline found with name: %s", sch_connection_name)
        
        existing_connections = [conn for conn in control_hub.connections if conn.name == sch_connection_name]
        
        if existing_connections:
            for conn in existing_connections:
                delete_connection(control_hub, conn)
                break
        else:
            logger.info("No connections found with name: %s", sch_connection_name)

if __name__ == "__main__":
    main()
EOT

python3 sx_conn_manager_cli.py start \
    --cred_id "${SCH_CRED_ID}" \
    --token "${SCH_TOKEN}" \
    --sch_connection_name "${INITIALS_PREFIX}-sx-db-benchmarks - SQLServer - ${DATABASE_NAME}" \
    --database_user "${DATABASE_USER}" \
    --database_pass "${DATABASE_PASS}" \
    --connection_string "jdbc:sqlserver://;serverName=${INITIALS_PREFIX}-sx-db-benchmarks;encrypt=true;trustServerCertificate=true;databaseName=${DATABASE_NAME}" \
    --hostname "http://${SDC_HOSTNAME}:18630"


cat <<'EOT' > shutdown_cleanup_script.sh
python3 /home/ubuntu/sx_conn_manager_cli.py stop \
    --cred_id "${SCH_CRED_ID}" \
    --token "${SCH_TOKEN}" \
    --sch_connection_name "${INITIALS_PREFIX}-sx-db-benchmarks - SQLServer - ${DATABASE_NAME}" \
    --database_user "${DATABASE_USER}" \
    --database_pass "${DATABASE_PASS}" \
    --connection_string "jdbc:sqlserver://;serverName=${INITIALS_PREFIX}-sx-db-benchmarks;encrypt=true;trustServerCertificate=true;databaseName=${DATABASE_NAME}" \
    --hostname "http://${SDC_HOSTNAME}:18630"
EOT

sudo chmod +x shutdown_cleanup_script.sh

