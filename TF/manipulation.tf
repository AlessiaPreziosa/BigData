# MANIPULATION LAYER:
# Every 15 minutes, Dataflow (subscriber of the topic) will read records and save them as a text file (.csv) in lake L0 
# applying an initial elaboration regarding technical data quality. 

locals {
  manipulation_apis = [
    "iam.googleapis.com",
    "stackdriver.googleapis.com",
    "pubsub.googleapis.com",
    "dataflow.googleapis.com",          # for Dataflow
    "compute.googleapis.com",           # create and run VMs
    "storage-component.googleapis.com", # for Storage
    "storage-api.googleapis.com"        # for Storage
  ]
}

# Create a project
resource "google_project" "manipulation_project" {
  name            = "Manipulation Layer"
  project_id      = "manipulation-layer"
  org_id          = var.org
  billing_account = var.billing
}

# Create a service account
resource "google_service_account" "manipulation_service_account" {
  account_id = "manipulation-service-account"

  project = google_project.manipulation_project.project_id
}

# Verify manipulation_apis are enabled
resource "google_project_service" "manipulation_apis" {
  for_each = toset(local.manipulation_apis)
  service  = each.key

  project = google_project.manipulation_project.project_id
}

# Create a Dataflow job: we assume to have a dataflow flex template job that defines how to:
# 1. Save data (of the last 15 minutes) from Pub Sub in the L0 Raw Storage and apply technical quality 
# 2. Refine data (functional quality) and save them from L0 Raw Storage into the L1 BigQuery dataset
# 3. Aggregate and enrich data based on similar charateristics saving data into the L2 BigQuery dataset 
# 4. Trigger, as soon as all new rows are added to the L2 Dataset, the algorithm deployed (customized code) on GKE 

resource "google_dataflow_flex_template_job" "dataflow" {
  name                    = "dataflow"
  container_spec_gcs_path = "${google_storage_bucket.dataflow_bucket.url}/templates/PubSubToGCS"

  machine_type = "n1-standard-1"
  max_workers  = 5
  num_workers  = 1
  provider     = google-beta
  region       = var.loc.region
  project      = google_project.manipulation_project.project_id
  parameters = {
    inputTopic           = "projects/${google_project.manipulation_project.project_id}/topics/${google_pubsub_topic.topic.name}"
    outputDirectory      = "gs://${google_storage_bucket.lake0_bucket.name}/output"
    windowDuration       = "15m"
    outputFilenameSuffix = ".csv"
  }
  service_account_email = google_service_account.manipulation_service_account.email
}

# Create a GCS bucket for storing Dataflow templates
resource "google_storage_bucket" "dataflow_bucket" {
  name     = "dataflow-bucket"
  location = var.loc.multi_region

  project       = google_project.manipulation_project.project_id
  force_destroy = true
}

# Grant Dataflow service account permission to read GCS bucket (Dataflow job)  
resource "google_storage_bucket_iam_member" "dataflow_bucket_iam" {
  bucket = google_storage_bucket.dataflow_bucket.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.manipulation_service_account.email}"
}

# Grant Dataflow service account permissions to launch pipeline
resource "google_project_iam_member" "dataflow_worker" {
  project = google_project.manipulation_project.project_id
  role    = "roles/dataflow.worker"
  member  = "serviceAccount:${google_service_account.manipulation_service_account.email}"
}

