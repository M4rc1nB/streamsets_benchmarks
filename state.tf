terraform {
  backend "gcs" {
    bucket  = "sx-benchmarks"
    prefix  = "terraform/mb-state"
  }
}