data "google_secret_manager_secret_version" "sx_platform_secret" {
  provider   = google
  secret     = "${var.your_initials}-sx-platform"
}

data "google_secret_manager_secret_version" "sqlserver_secret" {
  depends_on = [google_secret_manager_secret_version.sqlserver_secret_version]
  provider   = google
  secret     = google_secret_manager_secret.sqlserver_secret.name
}

data "google_secret_manager_secret_version" "oracle_secret" {
  depends_on = [google_secret_manager_secret_version.oracle_secret_version]
  provider   = google
  secret     = google_secret_manager_secret.oracle_secret.name
}

data "google_secret_manager_secret_version" "postgres_secret" {
  depends_on = [google_secret_manager_secret_version.postgres_secret_version]
  provider   = google
  secret     = google_secret_manager_secret.postgres_secret.name
}