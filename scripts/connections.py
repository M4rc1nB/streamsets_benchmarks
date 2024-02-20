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

def select_engine(control_hub, hostname, threshold_time_sec=100, max_attempts=10, sleep_time=60):
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

def start_logic(sch_connection_name, control_hub, database_user, database_pass, connection_string, hostname):
    existing_connections = [conn for conn in control_hub.connections if conn.name == sch_connection_name]
    
    if existing_connections:
        update_connection(control_hub, sch_connection_name, database_user, database_pass, connection_string)
    else:
        selected_engine = select_engine(control_hub, hostname)
        create_connection(control_hub, sch_connection_name, selected_engine, database_user, database_pass, connection_string)

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
        existing_connections = [conn for conn in control_hub.connections if conn.name == sch_connection_name]

        if existing_connections:
            for conn in existing_connections:
                delete_connection(control_hub, conn)
                break
        else:
            logger.info("No connections found with name: %s", sch_connection_name)

if __name__ == "__main__":
    main()