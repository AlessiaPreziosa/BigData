# EXPOSURE LAYER

locals {
  exposure_apis = [
    "iam.googleapis.com",
    "stackdriver.googleapis.com",
    "cloudfunctions.googleapis.com", # for Cloud Functions
    "run.googleapis.com",            # for Cloud Run
    "storage-component.googleapis.com",
    "storage-api.googleapis.com"
  ]
  roles = [
    "roles/run.invoker",
    "roles/cloudfunctions.invoker"
  ]
}

# Create a project
resource "google_project" "exposure_project" {
  name            = "Exposure Layer"
  project_id      = "exposure-layer"
  org_id          = var.org
  billing_account = var.billing
}

# Create a service account for the exposure layer
resource "google_service_account" "exposure_service_account" {
  account_id = "exposure-service-account"
  project    = google_project.exposure_project.project_id
}

# Create a service account for PowerBI
resource "google_service_account" "exposure_service_account_pbi" {
  account_id = "exposure-service-account-pbi"
  project    = google_project.exposure_project.project_id
}

# Create a service account for Jupyter
resource "google_service_account" "exposure_service_account_jupyter" {
  account_id = "exposure-service-account-jupyter"
  project    = google_project.exposure_project.project_id
}

# Verify exposure_apis are enabled
resource "google_project_service" "exposure_project_api" {
  for_each = toset(local.exposure_apis)
  service  = each.key

  project = google_project.exposure_project.project_id
}

# Create a bucket for the function object
resource "google_storage_bucket" "bucket_api_function" {
  name     = "bucket-api-function"
  location = var.loc.multi_region

  project                     = google_project.exposure_project.project_id
  uniform_bucket_level_access = true
}

# Create a function object
resource "google_storage_bucket_object" "object_api_function" {
  name   = "apis.zip"
  source = "./apis.zip"
  bucket = google_storage_bucket.bucket_api_function.name
}

# Create the Cloud Function 
resource "google_cloudfunctions_function" "api_function" {
  name    = "api-function"
  runtime = "python312"

  source_archive_bucket = google_storage_bucket.bucket_api_function.name
  source_archive_object = google_storage_bucket_object.object_api_function.name
  event_trigger {
    event_type = "google.cloud.bigquery.v2.DatasetService.UpdateDataset"
    resource   = google_bigquery_dataset.lake2_dataset.dataset_id
  }
  entry_point           = "update_wqi_value"
  timeout               = "300s"
  project               = google_project.exposure_project.project_id
  description           = "API function of the Exposure Layer to update WQI value on 3rd party monitoring system"
  service_account_email = google_service_account.exposure_service_account.email
  region                = var.loc.region
}

# Grant Consumption service account permissions to invoke the function (1st and 2nd gen)
resource "google_cloudfunctions_function_iam_member" "api_function_iam_members" {
  project        = google_project.exposure_project.project_id
  region         = var.loc.region
  cloud_function = google_cloudfunctions_function.api_function.name

  for_each = toset(local.roles)
  role     = each.key
  member   = "serviceAccount:${google_service_account.consumption_service_account.email}"
}

# Grant Exposure service account permissions to read the bucket function
resource "google_storage_bucket_iam_member" "exposure_bucket_iam_binding_0" {
  bucket = google_storage_bucket.bucket_api_function.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.exposure_service_account.email}"
}
