# Temporary storage for Dataflow
resource "google_storage_bucket" "dataflow_temp" {
  name          = "telecom-dataflow-temp-${var.project_id}"
  location      = var.region
  force_destroy = false
  
  encryption {
    default_kms_key_name = google_kms_crypto_key.gcs_key.id
  }
  
  lifecycle_rule {
    condition {
      age = 1
    }
    action {
      type = "Delete"
    }
  }
}

# GCS bucket for input data
resource "google_storage_bucket" "dataflow_input" {
  name          = "telecom-input-${var.project_id}"
  location      = var.region
  force_destroy = false
  
  encryption {
    default_kms_key_name = google_kms_crypto_key.gcs_key.id
  }
}

# GCS bucket for output data
resource "google_storage_bucket" "dataflow_output" {
  name          = "telecom-output-${var.project_id}"
  location      = var.region
  force_destroy = false
  
  encryption {
    default_kms_key_name = google_kms_crypto_key.gcs_key.id
  }
}

# ACTUAL DATAFLOW JOB - This runs your pii_masking_pipeline.py
resource "google_dataflow_flex_template_job" "pii_masking_pipeline" {
  name = "pii-masking-pipeline-${local.resource_suffix}"
  
  # This is the template that wraps your Python code
  container_spec_gcs_path = "gs://dataflow-templates-${var.region}/latest/flex/PII_Masking"
  
  temp_gcs_location = "gs://${google_storage_bucket.dataflow_temp.name}/temp"
  
  parameters = {
    project_id     = var.project_id
    input_path     = "gs://${google_storage_bucket.dataflow_input.name}/hadoop-data/*.json"
    output_table   = "${var.project_id}.prod_telecom_data.patients"
    dlp_template   = google_data_loss_prevention_inspect_template.pii_detection.name
    crypto_key     = google_kms_crypto_key.dataflow_key.id
    secret_key     = random_password.pseudonymization_secret.result
    required_fields = "patient_id,created_date"
  }
  
  # Service account for Dataflow workers
  service_account_email = google_service_account.dataflow_worker.email
  
  depends_on = [
    google_project_service.required_apis,
    google_bigquery_table.patients,
    google_data_loss_prevention_inspect_template.pii_detection
  ]
}

# Random secret for pseudonymization
resource "random_password" "pseudonymization_secret" {
  length  = 32
  special = false
}

# Service account for Dataflow workers
resource "google_service_account" "dataflow_worker" {
  account_id   = "telecom-dataflow-worker-${local.resource_suffix}"
  display_name = "telecom Dataflow Worker"
}

# Grant necessary permissions to Dataflow worker
resource "google_project_iam_member" "dataflow_worker_permissions" {
  for_each = toset([
    "roles/dataflow.worker",
    "roles/bigquery.dataEditor",
    "roles/bigquery.jobUser",
    "roles/storage.objectViewer",
    "roles/storage.objectAdmin",
    "roles/dlp.user",
    "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  ])
  
  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.dataflow_worker.email}"
}

# Output the job ID
output "dataflow_job_id" {
  value = google_dataflow_flex_template_job.pii_masking_pipeline.job_id
}
