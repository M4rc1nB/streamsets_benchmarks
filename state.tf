terraform {
  backend "gcs" {
    bucket  = "sx-benchmarks"
    prefix  = "terraform/default-state"
  }
}