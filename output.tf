output "db_instance_name" {
  value = google_compute_instance.sx-db-benchmarks.name
}

output "sdc_instance_name" {
  value = google_compute_instance.sx-sdc-benchmarks.name
}

output "oracle_password" {
  value = jsondecode(data.google_secret_manager_secret_version.oracle_secret.secret_data)["password"]
  sensitive = true
}

output "sx_platform_url" {
  value = jsondecode(data.google_secret_manager_secret_version.sx_platform_secret.secret_data)["streamsets_deployment_sch_url"]
  sensitive = true
}