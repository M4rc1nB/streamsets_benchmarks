resource "google_compute_instance" "sx-db-benchmarks" {
  name         = "${var.your_initials}-sx-db-benchmarks"
  machine_type = var.machine_setup["db"]
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts" # Ubuntu 20.04 LTS image
      size = 100
    }
  }

  network_interface {
    subnetwork = data.google_compute_subnetwork.subnet.self_link
  }

  service_account {
    email  = var.service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata_startup_script = templatefile("scripts/db.sh", {
      SQLSERVER_DATABASE_NAME = var.sqlserver_settings["database_name"],
      SQLSERVER_DATABASE_PASS = jsondecode(data.google_secret_manager_secret_version.sqlserver_secret.secret_data)["password"],
      SQLSERVER_DATABASE_USER = jsondecode(data.google_secret_manager_secret_version.sqlserver_secret.secret_data)["username"],
      POSTGRES_DATABASE_PASS = jsondecode(data.google_secret_manager_secret_version.postgres_secret.secret_data)["password"],
      POSTGRES_DATABASE_USER = jsondecode(data.google_secret_manager_secret_version.postgres_secret.secret_data)["username"],
      ORACLE_DATABASE_PASS = jsondecode(data.google_secret_manager_secret_version.oracle_secret.secret_data)["password"],
      SOURCE_USER = var.source_user,
      SOURCE_PASS = var.source_pass,
      INITIALS_PREFIX = var.your_initials
    })
  
  // Adding a persistent disk
  attached_disk {
    source = google_compute_disk.persistent_disk.self_link
    device_name = "${var.your_initials}-persistent-disk"
  }

  tags = ["${var.your_initials}-sx-db-benchmarks"]
}

// Define the persistent disk
resource "google_compute_disk" "persistent_disk" {
  name  = "${var.your_initials}-persistent-disk"
  type  = "pd-ssd" 
  size  = 300 # Size in GB
  zone  = var.zone
}

resource "google_compute_instance" "sx-sdc-benchmarks" {
  name         = "${var.your_initials}-sx-sdc-benchmarks"
  machine_type = var.machine_setup["sdc"]
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts" # Ubuntu 20.04 LTS image
      size  = 100
    }
  }

  network_interface {
    subnetwork = data.google_compute_subnetwork.subnet.self_link
  }

  service_account {
    email  = var.service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata_startup_script = templatefile("scripts/sdc.sh", {
      SDC_HOSTNAME = "${var.your_initials}-sdc-01"
      PLATFORM_URL = jsondecode(data.google_secret_manager_secret_version.sx_platform_secret.secret_data)["streamsets_deployment_sch_url"],
      DEPLOYMENT_ID = jsondecode(data.google_secret_manager_secret_version.sx_platform_secret.secret_data)["streamsets_deployment_id"],
      DEPLOYMENT_TOKEN = jsondecode(data.google_secret_manager_secret_version.sx_platform_secret.secret_data)["streamsets_deployment_token"],
      SCH_CRED_ID = jsondecode(data.google_secret_manager_secret_version.sx_platform_secret.secret_data)["streamsets_sch_cred_id"],
      SCH_TOKEN = jsondecode(data.google_secret_manager_secret_version.sx_platform_secret.secret_data)["streamsets_sch_token"],
      INITIALS_PREFIX = var.your_initials,
      DATABASE_NAME = var.sqlserver_settings["database_name"],
      DATABASE_PASS = jsondecode(data.google_secret_manager_secret_version.sqlserver_secret.secret_data)["password"],
      DATABASE_USER = jsondecode(data.google_secret_manager_secret_version.sqlserver_secret.secret_data)["username"],
      SOURCE_USER = var.source_user,
      SOURCE_PASS = var.source_pass
    })

    tags = ["${var.your_initials}-sx-sdc-benchmarks"]
}

# Grant access to the existing Cloud Storage bucket
resource "google_storage_bucket_iam_member" "storage_bucket_access" {
  bucket = "sx-benchmarks"
  role   = "roles/storage.admin"
  member = "serviceAccount:${var.service_account_email}"
}
