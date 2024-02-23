# StreamSets Benchmarks

This repository contains scripts and configuration files for benchmarking StreamSets Data Collector performance on Google Cloud Platform (GCP).

## Features

- Automated provisioning of Origins including Kafka, Postgres, SQL Server, and Oracle.
- Automated provisioning of StreamSets Data Collector.
- Automated provisioning of StreamSets Connections for added origins.
- Automated creation of StreamSets Pipelines in a ready-to-execute state.
- Infrastructure and StreamSets Platform cleanup on de-provisioning.

## To-Do:

- Develop StreamSets pipeline framework:
  - Implement start and stop events logging into `benchmark_events`.
  - Capture relevant benchmarking data.
  - Pre-build a set of configurations for various RDBMS.
- Reconfigure sources to make them more production-like.
- Add logic to sdk-cli.py to create and remove; Environment, Deployment and Access Token. This will be used on pre terraform steps and implemented into Makefile 

## Requirements

- **Terraform v1.7.3**: Ensure Terraform version 1.7.3 is installed.
- **GCP Service Account**: Create a service account on GCP with the following permissions:
  - Compute Admin
  - Secret Manager Admin
  - Service Account User
  - Storage Admin

- **StreamSets Platform Deployment**
  - Create Environment
  - Create Deployment 
  - Generate Access Token

## Setup

1. **Service Account Setup**:
   - Create a service account on GCP with the necessary permissions listed above.
   - Download the JSON key file for the service account.
   - Place the JSON key in the cloned repo folder with the default name `streamsets-se-9e4b.json`.

2. **Create Secret**:
   - Use Google Secret Manager to create a secret named `youruser-sx-platform`.
   - Replace `youruser` with your username, obtainable from the terminal using the `whoami` command.

3. **JSON Template**:
   - Utilize the following JSON template for configuring StreamSets deployment:

```json
{
  "streamsets_deployment_sch_url": "https://eu01.hub.streamsets.com",
  "streamsets_deployment_id": "",
  "streamsets_deployment_token": "",
  "streamsets_sch_cred_id": "",
  "streamsets_sch_token": ""
}
```
## Usage
    make: Terraform initialization
    make plan: Terraform plan to see changes
    make apply: Apply changes to GCP (auto approve enabled)
    make destroy: Destroy resources in GCP
    make clean: Clean up working files


## Table: benchmark_events

 - Table for tracing benchmarking events

| Field Name      | Data Type                      | Description                                       |
|-----------------|--------------------------------|---------------------------------------------------|
| test_case_id    | INT AUTO_INCREMENT             | Primary key, auto-incrementing                    |
| timestamp       | TIMESTAMP                      | Default: current timestamp                        |
| event_type      | ENUM('start', 'stop', 'error') | Type of event                                     |
| origin_type     | VARCHAR(255)                   | Type of origin                                    |
| destination_type| VARCHAR(255)                   | Type of destination                               |
| test_scenario   | VARCHAR(255)                   | Description of the test scenario                  |
| duration        | DECIMAL(10, 2)                 | Duration of the event (in seconds)                |
| errors          | TEXT                           | Details of any errors that occurred               |
| parameters      | TEXT                           | Additional parameters relevant to the event       |
| vm_spec         | VARCHAR(45)                    | Specifications of the virtual machine             |
