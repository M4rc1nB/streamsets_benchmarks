resource "random_password" "sqlserver_password" {
  length           = 20
  special          = true
  override_special = "_%@"
}

resource "random_password" "oracle_password" {
  length           = 20
  special          = true
  override_special = "_%@"
}

resource "random_password" "postgres_password" {
  length           = 20
  special          = true
  override_special = "_%@"
}