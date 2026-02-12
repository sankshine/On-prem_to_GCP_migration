# KMS keys for Cloud Storage encryption

# Key ring for GCS keys
resource "google_kms_key_ring" "gcs_keyring" {
  name     = "gcs-telecom-keyring-${local.resource_suffix}"
  location = var.region
  project  = var.project_id
  
  depends_on = [google_project_service.required_apis]
}

# Crypto key for GCS
resource "google_kms_crypto_key" "gcs_key" {
  name            = "gcs-telecom-key"
  key_ring        = google_kms_key_ring.gcs_keyring.id
  rotation_period = var.kms_key_rotation_period
  
  lifecycle {
    prevent_destroy = true
  }
  
  version_template {
    algorithm = var.kms_key_algorithm
  }
  
  labels = merge(
    local.common_labels,
    {
      purpose     = "gcs-encryption"
      sensitivity = "high"
    }
  )
}

# Grant GCS service account access to KMS key
data "google_storage_project_service_account" "gcs_account" {
  project = var.project_id
}

resource "google_kms_crypto_key_iam_member" "gcs_key_encrypter" {
  crypto_key_id = google_kms_crypto_key.gcs_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"
}

# Crypto key for Dataflow
resource "google_kms_key_ring" "dataflow_keyring" {
  name     = "dataflow-telecom-keyring-${local.resource_suffix}"
  location = var.region
  project  = var.project_id
}

resource "google_kms_crypto_key" "dataflow_key" {
  name            = "dataflow-telecom-key"
  key_ring        = google_kms_key_ring.dataflow_keyring.id
  rotation_period = var.kms_key_rotation_period
  
  version_template {
    algorithm = var.kms_key_algorithm
  }
}

# Grant Dataflow service account access
data "google_project" "project" {}

resource "google_kms_crypto_key_iam_member" "dataflow_key_encrypter" {
  crypto_key_id = google_kms_crypto_key.dataflow_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.project.number}@dataflow-service-producer-prod.iam.gserviceaccount.com"
}
