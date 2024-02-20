
# StreamSets Benchmarks

This repository contains scripts and configuration files for benchmarking StreamSets Data Collector performance on Google Cloud Platform (GCP).

## Requirements

- **Terraform v1.7.3**: Make sure to install Terraform version 1.7.3.
- **GCP Service Account**: Create a service account on GCP with the following grants:
  - Compute Admin
  - Secret Manager Admin
  - Service Account User
  - Storage Admin

## Setup

1. **Service Account Setup**:
   - Create a service account on GCP with the necessary permissions listed above.
   - Download the JSON key file for the service account.
   - Place JSON key in the cloned repo folder with the default name of `streamsets-se-9e4b.json`.

2. **Create Secret**:
   - Use Google Secret Manager to create a secret called `youruser-sx-platform`.
   - Replace `youruser` with your username, which can be obtained from the terminal with the `whoami` command.

3. **JSON Template**:
   - Use the following JSON template for configuring StreamSets deployment:

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