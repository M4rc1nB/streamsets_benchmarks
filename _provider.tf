terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "4.51.0"
    }
  }
}

provider "google" {
  credentials = file(var.cred_file_name)

  project = var.project_id
  region  = var.region
  zone    = var.zone
}

provider "random" {}