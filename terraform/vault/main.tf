terraform {
  backend "gcs" {
    bucket  = "company-terraform"
    prefix  = "vault-config/state"
    project = "company-dev"
    credentials = "/Users/mirkop/src/companydeveloper.json"
  }
}
# set up the kubernetes provider and the credentials
provider "kubernetes" {
   version = "~> 1.7"
   host     = "${google_container_cluster.appcluster.endpoint}"
   token = "${data.google_client_config.default.access_token}"
   cluster_ca_certificate = "${base64decode(google_container_cluster.appcluster.master_auth.0.cluster_ca_certificate)}"
   load_config_file = false
}

# just a dummy initializer
data "google_client_config" "default" {}


# create the application cluster here
resource "google_container_cluster" "appcluster" {
  name     = "${terraform.workspace}"
  location = "${var.location}"
  project  = "${var.project_id}"
  min_master_version = "${var.master_version}"
  resource_labels = {
      environment = "${var.environment}"
      product = "awesomeprod"
      createdby = "terraform"
    }


  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count = 1

  # Setting an empty username and password explicitly disables basic auth
  master_auth {
    username = ""
    password = ""
  }
  timeouts {
    create = "20m"
    delete = "60m"
  }
}

# defines the node pool for the cluster
resource "google_container_node_pool" "appcluster_nodes" {
  name       = "my-node-pool"
  location   = "${var.location}"
  project    = "$var.project_id}"
  cluster    = "${google_container_cluster.appcluster.name}"
  node_count = "${var.node_count}" 
  version = "${var.nodepool_version}"

  node_config {
    machine_type = "${var.machine_type}"

    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
  timeouts {
    create = "20m"
    delete = "60m"
  }
}

resource "google_compute_disk" "redis" {
  name  = "${terraform.workspace}-redis-data-disk"
  project = "${var.project_id}"
  type  = "pd-ssd"
  zone  = "${var.location}"
  size  = "5"
  labels = {
    environment = "${terraform.workspace}"
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

resource "google_service_account_key" "cloudsqlkey" {
  service_account_id = "cloudsql@cloudaccount.iam.gserviceaccount.com"
}

resource "kubernetes_namespace" "appnamespace" {
  metadata {
    annotations = {
      name = "${terraform.workspace}" 
    }  
    labels = {
      createdby = "terraform"
    }
  name = "${terraform.workspace}"
  }
}
resource "kubernetes_secret" "vault-credentials" {
  metadata {
    name = "vaultserviceaccount"
    namespace = "${terraform.workspace}"
  }
  data = {
    "credentials.json" = "${base64decode(google_service_account_key.sakey.private_key)}"
  }
  depends_on = ["kubernetes_namespace.appnamespace"]
}
resource "kubernetes_secret" "cloudsql-credentials" {
  metadata {
    name = "cloudsql-instance-credentials"
    namespace = "default"
  }
  data = {
    "credentials.json" = "${base64decode(google_service_account_key.cloudsqlkey.private_key)}"
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

#this runs the initial population of the cluster with base infrastructure components
resource "null_resource" "cluster-config" {
provisioner "local-exec" {
    command = "./base_tools.sh ${var.project_id} ${terraform.workspace} > base_tools.log"
  }

  depends_on = ["kubernetes_namespace.appnamespace"]
}

data "template_file" "kubeconfig" {
  template = "${file("${path.module}/kubeconfig-template.yaml")}"

  vars = {
    cluster_name    = "${google_container_cluster.appcluster.name}"
    user_name       = "${google_container_cluster.appcluster.master_auth.0.username}"
    user_password   = "${google_container_cluster.appcluster.master_auth.0.password}"
    endpoint        = "${google_container_cluster.appcluster.endpoint}"
    cluster_ca      = "${google_container_cluster.appcluster.master_auth.0.cluster_ca_certificate}"
    client_cert     = "${google_container_cluster.appcluster.master_auth.0.client_certificate}"
    client_cert_key = "${google_container_cluster.appcluster.master_auth.0.client_key}"
  }
}
