# CONSUMPTION LAYER: A custom microservice predicts the WQI value using L2 data via Google Kubernetes Engine.
# New and updated WQI values are then written in L2 dataset to be analyzed 
# by the exposure and visualitation layers (both in Jupyter Notebook and PowerBI dashboard)
# It then updates the 3rd party system by means of a standard API call 

locals {
  consumption_apis = [
    "iam.googleapis.com",
    "stackdriver.googleapis.com",
    "container.googleapis.com", # for GKE
    "compute.googleapis.com"
  ]
  roles = [
    "roles/iam.serviceAccountUser",
    "roles/container.admin",
    "roles/compute.networkAdmin"
  ]
}

# Create a project
resource "google_project" "consumption_project" {
  name            = "Consumption Layer"
  project_id      = "consumption-layer"
  org_id          = var.org
  billing_account = var.billing
}

# Create a service account
resource "google_service_account" "consumption_service_account" {
  account_id = "consumption-service-account"
  project    = google_project.consumption_project.project_id
}

# Verify consumption_apis are enabled
resource "google_project_service" "consumption_apis" {
  for_each = toset(local.consumption_apis)
  service  = each.key

  project = google_project.consumption_project.project_id
}

# Manages a Google Kubernetes Engine (GKE) cluster.
resource "google_container_cluster" "gke_cluster" {
  name = "gke-cluster" # The name of the cluster

  location = var.loc.region
  # location (region) in which the cluster master will be created, as well as the default node location 
  # the cluster will be a regional cluster with multiple masters spread across zones in the region, 
  # and with default node locations in those zones as well

  initial_node_count = 1
  # The number of nodes to create in this cluster's default node pool. 
  # In regional clusters, this is the number of nodes per zone.

  remove_default_node_pool = true
  # Deletes the default node pool upon cluster creation

  project = google_project.consumption_project.project_id
}

# Manages a node pool in a Google Kubernetes Engine (GKE) cluster separately from the cluster control plane.
resource "google_container_node_pool" "gke_node_pool" {
  cluster  = google_container_cluster.gke_cluster.name # The cluster to create the node pool for
  name     = "gke-node-pool"                           # The name of the node pool
  location = var.loc.region                            # Location of the cluster

  node_count = 2 # number of nodes per instance group
  node_config {
    machine_type    = "n1-standard-1"
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    service_account = google_service_account.consumption_service_account.email
  }

  project = google_project.consumption_project.project_id
}

resource "google_project_iam_member" "gke_iam" {
  project  = google_project.consumption_project.project_id
  for_each = toset(local.roles)
  role     = each.key
  member   = "serviceAccount:${google_service_account.consumption_service_account.email}"
}
