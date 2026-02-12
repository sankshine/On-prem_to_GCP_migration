# Terraform Variables
# Healthcare Data Migration Project

# ============================================================================
# PROJECT CONFIGURATION
# ============================================================================

variable "project_id" {
  description = "GCP Project ID for the healthcare migration"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project ID must be 6-30 characters, start with a letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "project_number" {
  description = "GCP Project Number (numeric ID)"
  type        = string
}

variable "region" {
  description = "Primary GCP region for resources"
  type        = string
  default     = "us-central1"
  
  validation {
    condition = contains([
      "us-central1", "us-east1", "us-east4", "us-west1", "us-west2"
    ], var.region)
    error_message = "Region must be a valid US region for HIPAA compliance."
  }
}

variable "secondary_region" {
  description = "Secondary GCP region for disaster recovery"
  type        = string
  default     = "us-east1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "cost_center" {
  description = "Cost center for billing allocation"
  type        = string
  default     = "healthcare-data-engineering"
}

# ============================================================================
# NETWORK CONFIGURATION
# ============================================================================

variable "dataflow_subnet_cidr" {
  description = "CIDR range for Dataflow subnet"
  type        = string
  default     = "172.16.1.0/24"
}

variable "management_subnet_cidr" {
  description = "CIDR range for management subnet"
  type        = string
  default     = "172.16.10.0/24"
}

variable "pod_cidr_range" {
  description = "Secondary CIDR range for Kubernetes pods"
  type        = string
  default     = "172.20.0.0/16"
}

variable "service_cidr_range" {
  description = "Secondary CIDR range for Kubernetes services"
  type        = string
  default     = "172.21.0.0/16"
}

variable "onprem_cidr_ranges" {
  description = "On-premises network CIDR ranges for VPN/Interconnect"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

# ============================================================================
# BIGQUERY CONFIGURATION
# ============================================================================

variable "bigquery_dataset_location" {
  description = "Location for BigQuery datasets"
  type        = string
  default     = "US"
  
  validation {
    condition     = contains(["US", "EU"], var.bigquery_dataset_location)
    error_message = "BigQuery location must be US or EU for multi-region."
  }
}

variable "bigquery_default_table_expiration_ms" {
  description = "Default table expiration in milliseconds (0 = never)"
  type        = number
  default     = 0
}

variable "bigquery_delete_contents_on_destroy" {
  description = "Whether to delete BigQuery tables on dataset destroy"
  type        = bool
  default     = false
}

variable "enable_bigquery_cmek" {
  description = "Enable customer-managed encryption keys for BigQuery"
  type        = bool
  default     = true
}

variable "bigquery_slot_capacity" {
  description = "BigQuery flex slot capacity for flat-rate pricing (0 = on-demand)"
  type        = number
  default     = 0
}

# ============================================================================
# CLOUD STORAGE CONFIGURATION
# ============================================================================

variable "gcs_storage_class" {
  description = "Default storage class for GCS buckets"
  type        = string
  default     = "STANDARD"
  
  validation {
    condition = contains([
      "STANDARD", "NEARLINE", "COLDLINE", "ARCHIVE"
    ], var.gcs_storage_class)
    error_message = "Storage class must be STANDARD, NEARLINE, COLDLINE, or ARCHIVE."
  }
}

variable "gcs_lifecycle_age_days" {
  description = "Number of days before transitioning to Coldline storage"
  type        = number
  default     = 90
}

variable "gcs_archive_age_days" {
  description = "Number of days before transitioning to Archive storage"
  type        = number
  default     = 365
}

variable "enable_gcs_versioning" {
  description = "Enable object versioning for GCS buckets"
  type        = bool
  default     = true
}

variable "enable_gcs_cmek" {
  description = "Enable customer-managed encryption keys for GCS"
  type        = bool
  default     = true
}

# ============================================================================
# DATAFLOW CONFIGURATION
# ============================================================================

variable "dataflow_max_workers" {
  description = "Maximum number of Dataflow workers"
  type        = number
  default     = 100
}

variable "dataflow_machine_type" {
  description = "Machine type for Dataflow workers"
  type        = string
  default     = "n1-standard-4"
  
  validation {
    condition = contains([
      "n1-standard-2", "n1-standard-4", "n1-standard-8",
      "n1-highmem-2", "n1-highmem-4", "n1-highmem-8"
    ], var.dataflow_machine_type)
    error_message = "Machine type must be a valid n1 series instance."
  }
}

variable "dataflow_disk_size_gb" {
  description = "Persistent disk size for Dataflow workers in GB"
  type        = number
  default     = 100
  
  validation {
    condition     = var.dataflow_disk_size_gb >= 100 && var.dataflow_disk_size_gb <= 10000
    error_message = "Disk size must be between 100 and 10000 GB."
  }
}

variable "dataflow_service_account_email" {
  description = "Service account email for Dataflow jobs"
  type        = string
  default     = ""
}

variable "enable_dataflow_streaming_engine" {
  description = "Enable Dataflow Streaming Engine for reduced latency"
  type        = bool
  default     = false
}

# ============================================================================
# CLOUD DLP CONFIGURATION
# ============================================================================

variable "dlp_inspection_likelihood" {
  description = "Minimum likelihood threshold for DLP findings"
  type        = string
  default     = "POSSIBLE"
  
  validation {
    condition = contains([
      "VERY_UNLIKELY", "UNLIKELY", "POSSIBLE", "LIKELY", "VERY_LIKELY"
    ], var.dlp_inspection_likelihood)
    error_message = "Likelihood must be a valid DLP likelihood level."
  }
}

variable "dlp_max_findings_per_item" {
  description = "Maximum findings per item (0 = unlimited)"
  type        = number
  default     = 0
}

variable "dlp_include_quote" {
  description = "Include matching quote in DLP findings"
  type        = bool
  default     = true
}

variable "enable_dlp_deidentification" {
  description = "Enable automatic DLP de-identification"
  type        = bool
  default     = true
}

# ============================================================================
# CLOUD KMS CONFIGURATION
# ============================================================================

variable "kms_key_rotation_period" {
  description = "KMS key rotation period in seconds (90 days default)"
  type        = string
  default     = "7776000s"
}

variable "kms_key_algorithm" {
  description = "KMS key algorithm"
  type        = string
  default     = "GOOGLE_SYMMETRIC_ENCRYPTION"
  
  validation {
    condition = contains([
      "GOOGLE_SYMMETRIC_ENCRYPTION",
      "AES_256_GCM",
      "AES_256_CBC"
    ], var.kms_key_algorithm)
    error_message = "Algorithm must be a valid KMS algorithm."
  }
}

variable "kms_prevent_destroy" {
  description = "Prevent KMS key destruction"
  type        = bool
  default     = true
}

# ============================================================================
# IAM CONFIGURATION
# ============================================================================

variable "data_engineer_members" {
  description = "List of data engineer user/service account emails"
  type        = list(string)
  default     = []
}

variable "data_analyst_members" {
  description = "List of data analyst user/service account emails"
  type        = list(string)
  default     = []
}

variable "security_auditor_members" {
  description = "List of security auditor user/service account emails"
  type        = list(string)
  default     = []
}

variable "enable_mfa_enforcement" {
  description = "Enforce MFA for all user accounts"
  type        = bool
  default     = true
}

variable "enable_workload_identity" {
  description = "Enable Workload Identity for GKE clusters"
  type        = bool
  default     = true
}

# ============================================================================
# SECURITY CONFIGURATION
# ============================================================================

variable "enable_vpc_service_controls" {
  description = "Enable VPC Service Controls perimeter"
  type        = bool
  default     = true
}

variable "access_policy_id" {
  description = "Access Context Manager policy ID for VPC Service Controls"
  type        = string
  default     = ""
}

variable "allowed_ip_ranges" {
  description = "IP ranges allowed to access GCP resources"
  type        = list(string)
  default     = []
}

variable "enable_binary_authorization" {
  description = "Enable Binary Authorization for container security"
  type        = bool
  default     = true
}

variable "enable_security_command_center" {
  description = "Enable Security Command Center"
  type        = bool
  default     = true
}

# ============================================================================
# MONITORING AND ALERTING
# ============================================================================

variable "alert_email" {
  description = "Email address for monitoring alerts"
  type        = string
}

variable "enable_pagerduty" {
  description = "Enable PagerDuty integration"
  type        = bool
  default     = false
}

variable "pagerduty_service_key" {
  description = "PagerDuty service integration key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "pagerduty_auth_token" {
  description = "PagerDuty API auth token"
  type        = string
  default     = ""
  sensitive   = true
}

variable "log_retention_days" {
  description = "Log retention period in days"
  type        = number
  default     = 2555  # 7 years for HIPAA
  
  validation {
    condition     = var.log_retention_days >= 2555
    error_message = "Log retention must be at least 7 years (2555 days) for HIPAA compliance."
  }
}

variable "enable_uptime_checks" {
  description = "Enable uptime monitoring checks"
  type        = bool
  default     = true
}

# ============================================================================
# BACKUP AND DISASTER RECOVERY
# ============================================================================

variable "enable_bigquery_snapshots" {
  description = "Enable automated BigQuery table snapshots"
  type        = bool
  default     = true
}

variable "snapshot_frequency_days" {
  description = "Frequency of snapshots in days"
  type        = number
  default     = 1
}

variable "snapshot_retention_days" {
  description = "Retention period for snapshots in days"
  type        = number
  default     = 30
}

variable "enable_cross_region_replication" {
  description = "Enable cross-region replication for DR"
  type        = bool
  default     = true
}

# ============================================================================
# COMPLIANCE CONFIGURATION
# ============================================================================

variable "enable_hipaa_compliance" {
  description = "Enable HIPAA compliance controls"
  type        = bool
  default     = true
}

variable "enable_data_residency" {
  description = "Enable data residency constraints"
  type        = bool
  default     = true
}

variable "data_classification_labels" {
  description = "Data classification labels for resources"
  type        = map(string)
  default = {
    "phi"       = "true"
    "pii"       = "true"
    "sensitive" = "true"
  }
}

# ============================================================================
# COLLIBRA INTEGRATION
# ============================================================================

variable "collibra_url" {
  description = "Collibra instance URL"
  type        = string
  default     = ""
}

variable "collibra_username" {
  description = "Collibra API username"
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_collibra_sync" {
  description = "Enable automatic Collibra metadata synchronization"
  type        = bool
  default     = true
}

variable "collibra_sync_frequency" {
  description = "Collibra sync frequency (cron expression)"
  type        = string
  default     = "0 2 * * *"  # Daily at 2 AM
}

# ============================================================================
# COST MANAGEMENT
# ============================================================================

variable "billing_account_id" {
  description = "Billing account ID for budget alerts"
  type        = string
}

variable "monthly_budget_amount" {
  description = "Monthly budget amount in USD"
  type        = number
  default     = 20000
  
  validation {
    condition     = var.monthly_budget_amount > 0
    error_message = "Budget amount must be greater than 0."
  }
}

variable "enable_cost_anomaly_detection" {
  description = "Enable cost anomaly detection alerts"
  type        = bool
  default     = true
}

# ============================================================================
# MIGRATION CONFIGURATION
# ============================================================================

variable "hadoop_cluster_endpoints" {
  description = "List of Hadoop cluster endpoint URLs"
  type        = list(string)
  default     = []
}

variable "hadoop_username" {
  description = "Hadoop cluster username"
  type        = string
  default     = ""
  sensitive   = true
}

variable "migration_batch_size" {
  description = "Number of tables to migrate in each batch"
  type        = number
  default     = 10
}

variable "enable_migration_validation" {
  description = "Enable post-migration data validation"
  type        = bool
  default     = true
}

variable "validation_sample_percentage" {
  description = "Percentage of data to validate (0-100)"
  type        = number
  default     = 10
  
  validation {
    condition     = var.validation_sample_percentage >= 0 && var.validation_sample_percentage <= 100
    error_message = "Sample percentage must be between 0 and 100."
  }
}

# ============================================================================
# FEATURE FLAGS
# ============================================================================

variable "enable_cloud_armor" {
  description = "Enable Cloud Armor for DDoS protection"
  type        = bool
  default     = true
}

variable "enable_private_google_access" {
  description = "Enable Private Google Access for subnets"
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "Enable VPC flow logs"
  type        = bool
  default     = true
}

variable "enable_container_scanning" {
  description = "Enable container vulnerability scanning"
  type        = bool
  default     = true
}

# ============================================================================
# TAGGING AND LABELS
# ============================================================================

variable "additional_labels" {
  description = "Additional labels to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "resource_name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "healthcare"
  
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.resource_name_prefix))
    error_message = "Prefix must start with a letter and contain only lowercase letters, numbers, and hyphens."
  }
}
