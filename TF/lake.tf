# LAKE LAYER

locals {
  lake_apis = [
    "iam.googleapis.com",
    "stackdriver.googleapis.com",
    "bigquery.googleapis.com", # for BigQuery
    "storage-component.googleapis.com",
    "storage-api.googleapis.com"
  ]
}

# Create a project
resource "google_project" "lake_project" {
  name            = "Lake Layer"
  project_id      = "lake-layer"
  org_id          = var.org
  billing_account = var.billing
}

# Verify lake_apis are enabled
resource "google_project_service" "lake_apis" {
  for_each = toset(local.lake_apis)
  service  = each.key

  project = google_project.lake_project.project_id
}

# L0 Raw Storage: Data are stored in standardized raw format and masked with respect to regulations. 
resource "google_storage_bucket" "lake0_bucket" {
  name     = "lake0_bucket"
  location = var.loc.multi_region

  project                     = google_project.lake_project.project_id
  uniform_bucket_level_access = true
}

# Grant Dataflow service account Admin permissions on the GCS bucket (L0 Raw Storage) 
resource "google_storage_bucket_iam_member" "lake0_bucket_iam" {
  bucket = google_storage_bucket.lake0_bucket.id
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.manipulation_service_account.email}"
}

# L1 Curated: Refined data are stored 
resource "google_bigquery_dataset" "lake1_dataset" {
  dataset_id = "lake1_dataset"

  friendly_name = "L1 Curated"
  location      = var.loc.multi_region
  project       = google_project.lake_project.project_id
  access {
    role          = "OWNER"
    user_by_email = google_service_account.manipulation_service_account.email
  }
  description = "Refined data are stored"
}

# L2 Ready: Aggregated and enriched data are stored
resource "google_bigquery_dataset" "lake2_dataset" {
  dataset_id = "lake2_dataset"

  friendly_name = "L2 Ready"
  location      = var.loc.multi_region
  project       = google_project.lake_project.project_id
  access {
    role          = "OWNER"
    user_by_email = google_service_account.manipulation_service_account.email
  }
  access {
    role          = "WRITER"
    user_by_email = google_service_account.consumption_service_account.email
  }
  access {
    role          = "READER"
    user_by_email = google_service_account.exposure_service_account_pbi.email
  }
  access {
    role          = "READER"
    user_by_email = google_service_account.exposure_service_account_jupyter.email
  }

  description = "Aggregated and enriched data are stored"
}


