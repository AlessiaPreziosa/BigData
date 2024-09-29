# LANDING LAYER: 
# An external water monitoring system collects data from sensors all over India and pushes data in real-time to the data platform. 
# The data stream is integrated into the data platform via a Pub/Sub component that permits asynchronous communication. 
# The publisher is, in this case, the external system which sends events regardless of how and when these will be processed. 

locals {
  landing_apis = [
    "pubsub.googleapis.com",     # for pub sub component
    "iam.googleapis.com",        # for iam roles
    "stackdriver.googleapis.com" # for metrics monitoring
  ]
}

# Create a project for the landing layer
resource "google_project" "landing_project" {
  name            = "Landing Layer"
  project_id      = "landing-layer"
  org_id          = var.org
  billing_account = var.billing
}

# Create a service account to manage the Pub Sub component
resource "google_service_account" "landing_service_account" {
  account_id = "landing-service-account"

  project = google_project.landing_project.project_id
}

# Create a service account for the external system
resource "google_service_account" "external_service_account" {
  account_id = "external-service-account"

  project = google_project.landing_project.project_id
}

# Verify landing_apis are enabled
resource "google_project_service" "landing_apis" {
  for_each = toset(local.landing_apis)
  service  = each.key

  project = google_project.landing_project.project_id
}

# Create a Pub/Sub Topic
resource "google_pubsub_topic" "topic" {
  name = "topic"

  project                    = google_project.landing_project.project_id
  message_retention_duration = "3600s" # indicates the minimum duration to retain a message after it is published to the topic
}

# Create a Pub/Sub Subscription (pull style)
resource "google_pubsub_subscription" "subscription" {
  name  = "subscription"
  topic = google_pubsub_topic.topic.id

  project                    = google_project.landing_project.project_id
  message_retention_duration = "3600s"
  retain_acked_messages      = true
  ack_deadline_seconds       = 600
  expiration_policy {
    ttl = ""
  }
}

# Provide access to modify topics and subscriptions, and access to publish and consume messages.
resource "google_project_iam_member" "pubsub_iam" {
  project = google_project.landing_project.project_id
  role    = "roles/pubsub.editor"
  member  = "serviceAccount:${google_service_account.landing_service_account.email}"
}

# Grant External service account permission to publish messages to topic (publisher)
resource "google_pubsub_topic_iam_member" "publisher" {
  topic   = google_pubsub_topic.topic.id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.external_service_account.email}"
  project = google_project.landing_project.project_id
}

# Grant Dataflow service account permission to consume messages from topic (subscriber)
resource "google_pubsub_topic_iam_member" "dataflow_puller" {
  depends_on = [google_pubsub_subscription.subscription]
  topic      = google_pubsub_topic.topic.id
  role       = "roles/pubsub.subscriber"
  member     = "serviceAccount:${google_service_account.manipulation_service_account.email}"
  project    = google_project.landing_project.project_id
}

