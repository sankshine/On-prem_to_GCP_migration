# Cloud Function to sync metadata to Collibra

# Cloud Function source code
resource "google_storage_bucket_object" "collibra_sync_function" {
  name   = "collibra-sync-function/index.zip"
  bucket = google_storage_bucket.dataflow_temp.name
  
  # Create a simple zip file with the function code
  source = data.archive_file.collibra_sync_function.output_path
  depends_on = [data.archive_file.collibra_sync_function]
}

# Create zip file of the Cloud Function
data "archive_file" "collibra_sync_function" {
  type        = "zip"
  output_path = "${path.module}/collibra-sync-function.zip"
  
  source {
    content  = <<-EOT
const functions = require('@google-cloud/functions-framework');
const {BigQuery} = require('@google-cloud/bigquery');
const axios = require('axios');

// Cloud Function to sync BigQuery metadata to Collibra
functions.http('syncToCollibra', async (req, res) => {
  try {
    const bigquery = new BigQuery();
    const collibraUrl = process.env.COLLIBRA_URL;
    const collibraUsername = process.env.COLLIBRA_USERNAME;
    const collibraApiKey = process.env.COLLIBRA_API_KEY;
    
    // Get BigQuery datasets
    const [datasets] = await bigquery.getDatasets();
    
    for (const dataset of datasets) {
      // Get tables in dataset
      const [tables] = await dataset.getTables();
      
      for (const table of tables) {
        // Get table schema
        const [metadata] = await table.getMetadata();
        
        // Format metadata for Collibra
        const collibraAsset = {
          name: table.id,
          type: 'BigQuery Table',
          domain: 'Telecom Data',
          attributes: {
            description: metadata.schema?.description || '',
            columnCount: metadata.schema?.fields?.length || 0,
            created: metadata.created,
            lastModified: metadata.lastModifiedTime,
            projectId: metadata.tableReference.projectId,
            datasetId: metadata.tableReference.datasetId
          }
        };
        
        // Send to Collibra API
        if (collibraUrl && collibraApiKey) {
          await axios.post(`${collibraUrl}/rest/2.0/assets`, collibraAsset, {
            auth: {
              username: collibraUsername,
              password: collibraApiKey
            }
          });
        }
      }
    }
    
    res.status(200).send('Sync completed successfully');
  } catch (error) {
    console.error('Error syncing to Collibra:', error);
    res.status(500).send('Sync failed: ' + error.message);
  }
});
EOT
    filename = "index.js"
  }
  
  source {
    content  = <<-EOT
{
  "name": "collibra-sync-function",
  "version": "1.0.0",
  "description": "Sync BigQuery metadata to Collibra",
  "main": "index.js",
  "dependencies": {
    "@google-cloud/bigquery": "^6.0.0",
    "@google-cloud/functions-framework": "^3.0.0",
    "axios": "^1.0.0"
  }
}
EOT
    filename = "package.json"
  }
}

# Cloud Function to sync metadata to Collibra
resource "google_cloudfunctions2_function" "collibra_sync" {
  count = var.enable_collibra_sync ? 1 : 0
  
  name     = "collibra-sync-${local.resource_suffix}"
  location = var.region
  
  build_config {
    runtime     = "nodejs18"
    entry_point = "syncToCollibra"
    
    source {
      storage_source {
        bucket = google_storage_bucket.dataflow_temp.name
        object = google_storage_bucket_object.collibra_sync_function.name
      }
    }
  }
  
  service_config {
    max_instance_count = 1
    available_memory   = "256Mi"
    timeout_seconds    = 60
    
    environment_variables = {
      COLLIBRA_URL      = var.collibra_url
      COLLIBRA_USERNAME = var.collibra_username
      COLLIBRA_API_KEY  = var.collibra_api_key != "" ? var.collibra_api_key : "not-set"
    }
    
    service_account_email = google_service_account.collibra_sync_sa[0].email
  }
  
  depends_on = [
    google_project_service.required_apis,
    google_secret_manager_secret.collibra_api_key
  ]
}

# Service account for Collibra sync
resource "google_service_account" "collibra_sync_sa" {
  count = var.enable_collibra_sync ? 1 : 0
  
  account_id   = "collibra-sync-sa-${local.resource_suffix}"
  display_name = "Collibra Sync Service Account"
}

# IAM permissions for Collibra sync
resource "google_project_iam_member" "collibra_sync_permissions" {
  count = var.enable_collibra_sync ? 1 : 0
  
  project = var.project_id
  role    = "roles/bigquery.metadataViewer"
  member  = "serviceAccount:${google_service_account.collibra_sync_sa[0].email}"
}

# Secret for Collibra API key
resource "google_secret_manager_secret" "collibra_api_key" {
  count = var.enable_collibra_sync && var.collibra_url != "" ? 1 : 0
  
  secret_id = "collibra-api-key-${local.resource_suffix}"
  
  replication {
    auto {}
  }
}

# Secret version for Collibra API key
resource "google_secret_manager_secret_version" "collibra_api_key" {
  count = var.enable_collibra_sync && var.collibra_url != "" ? 1 : 0
  
  secret      = google_secret_manager_secret.collibra_api_key[0].id
  secret_data = var.collibra_api_key != "" ? var.collibra_api_key : "dummy-key"
}

# Cloud Scheduler to trigger sync daily
resource "google_cloud_scheduler_job" "collibra_sync_schedule" {
  count = var.enable_collibra_sync && var.collibra_url != "" ? 1 : 0
  
  name     = "collibra-sync-schedule-${local.resource_suffix}"
  region   = var.region
  schedule = var.collibra_sync_frequency
  
  http_target {
    http_method = "POST"
    uri         = google_cloudfunctions2_function.collibra_sync[0].service_config[0].uri
    
    oidc_token {
      service_account_email = google_service_account.collibra_sync_sa[0].email
    }
  }
}

# Add Collibra API key variable
variable "collibra_api_key" {
  description = "Collibra API key"
  type        = string
  default     = ""
  sensitive   = true
}
