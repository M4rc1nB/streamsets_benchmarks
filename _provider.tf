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

  project = "streamsets-se-9e4b"
  region  = "europe-west1"
  zone    = "europe-west1-c"
}

provider "random" {}