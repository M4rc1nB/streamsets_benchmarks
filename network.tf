data "google_compute_subnetwork" "subnet" {
  name    = "se-bench-subnet-01"
  region  = "europe-west1"
}

resource "google_compute_firewall" "internal-communication" {
  name    = "internal-communication"
  network = "se-bench"

  allow {
    protocol = "icmp" # Allow ICMP (ping) for testing connectivity
  }

  allow {
    protocol = "tcp"
    ports    = ["0-65535"] # Allow all TCP ports for full connectivity
  }

  source_tags = ["${var.your_initials}-sx-db-benchmarks", "${var.your_initials}-sx-sdc-benchmarks"]
  target_tags = ["${var.your_initials}-sx-db-benchmarks", "${var.your_initials}-sx-sdc-benchmarks"]
}


output "subnet_id" {
  value = data.google_compute_subnetwork.subnet.id
}