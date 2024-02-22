#Personal setup
variable "cred_file_name" {
default  = "streamsets-se-9e4b.json"
}

variable "service_account_email" {
default  = "marcin@streamsets-se-9e4b.iam.gserviceaccount.com"
}

variable "your_initials" {
default = "your_username_is_auto_detected" 
}

#GCP Compute Settings
variable "machine_setup" {
default ={
    db = "e2-standard-16"
    sdc = "e2-highmem-8"
    }
}

variable "db_disk_size" {
    default = 100
}

#GCP Auth
variable "project_id" {
default  = "streamsets-se-9e4b"
}

variable "region" {
default  = "europe-west1" 
}

variable "zone" {
default  = "europe-west1-c" 
}

#Database Settings
variable "sqlserver_settings" {
  default = {
    database_name = "AdventureWorksDW2022"
  }
}

variable "postgres_settings" {
  default = {
    database_name = ""
  }
}

variable "source_user" {
  default = "streamsets"
}

variable "source_pass" {
  default = "StreamSets@24"
}

