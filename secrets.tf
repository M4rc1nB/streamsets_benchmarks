resource "google_secret_manager_secret" "sqlserver_secret" {
  provider   = google
  project    = var.project_id
  secret_id  = "${var.your_initials}-sx-db-sqlserver"

  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret" "oracle_secret" {
  provider   = google
  project    = var.project_id
  secret_id  = "${var.your_initials}-sx-db-oracle"

  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret" "postgres_secret" {
  provider   = google
  project    = var.project_id
  secret_id  = "${var.your_initials}-sx-db-postgres"

  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "sqlserver_secret_version" {
  provider = google
  secret   = google_secret_manager_secret.sqlserver_secret.name

  secret_data = jsonencode({
    username = "SA",
    password = random_password.sqlserver_password.result
  })
}

resource "google_secret_manager_secret_version" "oracle_secret_version" {
  provider = google
  secret   = google_secret_manager_secret.oracle_secret.name

  secret_data = jsonencode({
    username = "SYSTEM",
    password = random_password.oracle_password.result
  })
}

resource "google_secret_manager_secret_version" "postgres_secret_version" {
  provider = google
  secret   = google_secret_manager_secret.postgres_secret.name

  secret_data = jsonencode({
    username = "postgres",
    password = random_password.postgres_password.result
  })
}