terraform {
  backend "gcs" {
    bucket  = "company-terraform"
    prefix  = "vault-config/state"
    project = "company-dev"
    credentials = "/Users/mirkop/src/companysulu/platform/auth-keys/developer.json"
  }
}

resource "google_storage_bucket" "vault-storage" {
  name     = "${terraform.workspace}-vault-storage"
  project  = "${var.project_id}"
  location = "${var.vault_storage_location}"
}


resource "google_service_account" "vault-sa" {
  account_id = "${terraform.workspace}-vault-server"
  project    = "${var.project_id}"
}

resource "google_service_account_key" "sakey" {
  service_account_id = "${google_service_account.vault-sa.name}"
}


resource "kubernetes_secret" "vault-credentials" {
  metadata = {
    name = "vaultserviceaccount"
    namespace = "${terraform.workspace}"
  }
  data {
    credentials.json = "${base64decode(google_service_account_key.sakey.private_key)}"
  }
}

resource "google_storage_bucket_iam_member" "bucket_member" {
  bucket = "${terraform.workspace}-vault-storage"
  role        = "roles/storage.objectAdmin"
  member      = "serviceAccount:${google_service_account.vault-sa.email}"
}

resource "google_storage_bucket_iam_member" "legacy_bucket_member" {
  bucket = "${terraform.workspace}-vault-storage"
  role        = "roles/storage.legacyBucketReader"
  member      = "serviceAccount:${google_service_account.vault-sa.email}"
}

resource "google_storage_bucket_iam_member" "backupbucket_member" {
  bucket = "${var.project_id}-vaultbackup"
  role        = "roles/storage.objectCreator"
  member      = "serviceAccount:${google_service_account.vault-sa.email}"
}
