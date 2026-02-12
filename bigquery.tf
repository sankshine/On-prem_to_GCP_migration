# BigQuery Infrastructure Configuration
# Healthcare Data Migration Project

# ============================================================================
# KMS KEY FOR BIGQUERY ENCRYPTION
# ============================================================================

resource "google_kms_key_ring" "bigquery_keyring" {
  name     = "bigquery-healthcare-keyring-${local.resource_suffix}"
  location = var.region
  project  = var.project_id
  
  depends_on = [google_project_service.required_apis]
}

resource "google_kms_crypto_key" "bigquery_key" {
  name            = "bigquery-healthcare-key"
  key_ring        = google_kms_key_ring.bigquery_keyring.id
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
      purpose     = "bigquery-encryption"
      sensitivity = "high"
    }
  )
}

# Grant BigQuery service account access to encryption key
resource "google_project_service_identity" "bigquery_sa" {
  provider = google-beta
  project  = var.project_id
  service  = "bigquery.googleapis.com"
}

resource "google_kms_crypto_key_iam_member" "bigquery_key_encrypter" {
  crypto_key_id = google_kms_crypto_key.bigquery_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_project_service_identity.bigquery_sa.email}"
}

# ============================================================================
# BIGQUERY DATASETS
# ============================================================================

# Production Healthcare Data Dataset
resource "google_bigquery_dataset" "prod_healthcare_data" {
  dataset_id                 = "prod_healthcare_data"
  friendly_name              = "Production Healthcare Data"
  description                = "Production healthcare data migrated from Hadoop - contains PHI"
  location                   = var.bigquery_dataset_location
  project                    = var.project_id
  delete_contents_on_destroy = var.bigquery_delete_contents_on_destroy
  
  default_table_expiration_ms = var.bigquery_default_table_expiration_ms
  
  default_encryption_configuration {
    kms_key_name = google_kms_crypto_key.bigquery_key.id
  }
  
  access {
    role          = "OWNER"
    user_by_email = google_service_account.dataflow_load_sa.email
  }
  
  access {
    role          = "READER"
    special_group = "projectReaders"
  }
  
  labels = merge(
    local.common_labels,
    var.data_classification_labels,
    {
      dataset_type = "production"
      contains_phi = "true"
    }
  )
  
  depends_on = [
    google_kms_crypto_key_iam_member.bigquery_key_encrypter
  ]
}

# Development/Testing Dataset
resource "google_bigquery_dataset" "dev_healthcare_data" {
  count = var.environment == "prod" ? 1 : 0
  
  dataset_id                 = "dev_healthcare_data"
  friendly_name              = "Development Healthcare Data"
  description                = "Development/testing dataset - de-identified data only"
  location                   = var.bigquery_dataset_location
  project                    = var.project_id
  delete_contents_on_destroy = true
  
  default_table_expiration_ms = 7776000000  # 90 days
  
  default_encryption_configuration {
    kms_key_name = google_kms_crypto_key.bigquery_key.id
  }
  
  labels = merge(
    local.common_labels,
    {
      dataset_type = "development"
      contains_phi = "false"
    }
  )
  
  depends_on = [
    google_kms_crypto_key_iam_member.bigquery_key_encrypter
  ]
}

# Audit Logs Dataset
resource "google_bigquery_dataset" "audit_logs" {
  dataset_id                 = "audit_logs"
  friendly_name              = "Audit Logs"
  description                = "Audit logs for compliance and security monitoring"
  location                   = var.bigquery_dataset_location
  project                    = var.project_id
  delete_contents_on_destroy = false
  
  default_table_expiration_ms = 0  # Never expire
  
  default_encryption_configuration {
    kms_key_name = google_kms_crypto_key.bigquery_key.id
  }
  
  access {
    role          = "OWNER"
    user_by_email = google_service_account.logging_sa.email
  }
  
  access {
    role          = "READER"
    special_group = "projectReaders"
  }
  
  labels = merge(
    local.common_labels,
    {
      dataset_type = "audit"
      retention    = "7-years"
    }
  )
  
  depends_on = [
    google_kms_crypto_key_iam_member.bigquery_key_encrypter
  ]
}

# ============================================================================
# BIGQUERY TABLES - PATIENT DATA
# ============================================================================

resource "google_bigquery_table" "patients" {
  dataset_id          = google_bigquery_dataset.prod_healthcare_data.dataset_id
  table_id            = "patients"
  deletion_protection = true
  
  description = "Patient demographic and identification data - MASKED"
  
  time_partitioning {
    type  = "DAY"
    field = "created_date"
  }
  
  clustering = ["patient_id", "zip_code"]
  
  schema = jsonencode([
    {
      name        = "patient_id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Unique patient identifier (pseudonymized)"
    },
    {
      name        = "patient_name"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Patient name (pseudonymized)"
    },
    {
      name        = "date_of_birth"
      type        = "DATE"
      mode        = "NULLABLE"
      description = "Date of birth (shifted ±180 days)"
    },
    {
      name        = "gender"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Patient gender"
    },
    {
      name        = "ssn"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Social Security Number (tokenized)"
    },
    {
      name        = "medical_record_number"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "MRN (tokenized)"
    },
    {
      name        = "email"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Email address (masked)"
    },
    {
      name        = "phone"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Phone number (last 4 digits only)"
    },
    {
      name        = "address"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Street address (removed)"
    },
    {
      name        = "city"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "City (removed for ZIP < 20000)"
    },
    {
      name        = "state"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "State"
    },
    {
      name        = "zip_code"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "ZIP code (3-digit for small populations)"
    },
    {
      name        = "created_date"
      type        = "DATE"
      mode        = "REQUIRED"
      description = "Record creation date (partition key)"
    },
    {
      name        = "updated_date"
      type        = "TIMESTAMP"
      mode        = "NULLABLE"
      description = "Last update timestamp"
    },
    {
      name        = "source_system"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Source system (Hadoop)"
    },
    {
      name        = "masking_applied"
      type        = "BOOLEAN"
      mode        = "REQUIRED"
      description = "Indicates if masking has been applied"
    }
  ])
  
  labels = merge(
    local.common_labels,
    {
      table_type  = "patient-master"
      contains_phi = "true"
      masked      = "true"
    }
  )
}

# ============================================================================
# BIGQUERY TABLES - CLINICAL DATA
# ============================================================================

resource "google_bigquery_table" "encounters" {
  dataset_id          = google_bigquery_dataset.prod_healthcare_data.dataset_id
  table_id            = "encounters"
  deletion_protection = true
  
  description = "Patient encounters and visits"
  
  time_partitioning {
    type  = "DAY"
    field = "encounter_date"
  }
  
  clustering = ["patient_id", "facility_id", "encounter_type"]
  
  schema = jsonencode([
    {
      name        = "encounter_id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Unique encounter identifier"
    },
    {
      name        = "patient_id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Patient identifier (pseudonymized)"
    },
    {
      name        = "facility_id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Facility identifier"
    },
    {
      name        = "provider_id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Provider identifier (pseudonymized)"
    },
    {
      name        = "encounter_date"
      type        = "DATE"
      mode        = "REQUIRED"
      description = "Encounter date (shifted ±180 days)"
    },
    {
      name        = "encounter_type"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Type of encounter (inpatient, outpatient, emergency)"
    },
    {
      name        = "admission_datetime"
      type        = "TIMESTAMP"
      mode        = "NULLABLE"
      description = "Admission timestamp (shifted)"
    },
    {
      name        = "discharge_datetime"
      type        = "TIMESTAMP"
      mode        = "NULLABLE"
      description = "Discharge timestamp (shifted)"
    },
    {
      name        = "diagnosis_codes"
      type        = "STRING"
      mode        = "REPEATED"
      description = "ICD-10 diagnosis codes"
    },
    {
      name        = "procedure_codes"
      type        = "STRING"
      mode        = "REPEATED"
      description = "CPT procedure codes"
    }
  ])
  
  labels = merge(
    local.common_labels,
    {
      table_type   = "clinical"
      contains_phi = "true"
      masked       = "true"
    }
  )
}

resource "google_bigquery_table" "claims" {
  dataset_id          = google_bigquery_dataset.prod_healthcare_data.dataset_id
  table_id            = "claims"
  deletion_protection = true
  
  description = "Healthcare claims and billing data"
  
  time_partitioning {
    type  = "DAY"
    field = "claim_date"
  }
  
  clustering = ["patient_id", "payer_id", "claim_status"]
  
  schema = jsonencode([
    {
      name        = "claim_id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Unique claim identifier"
    },
    {
      name        = "patient_id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Patient identifier (pseudonymized)"
    },
    {
      name        = "encounter_id"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Associated encounter ID"
    },
    {
      name        = "payer_id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Insurance payer identifier"
    },
    {
      name        = "claim_date"
      type        = "DATE"
      mode        = "REQUIRED"
      description = "Claim submission date"
    },
    {
      name        = "service_date"
      type        = "DATE"
      mode        = "REQUIRED"
      description = "Date of service (shifted)"
    },
    {
      name        = "claim_amount"
      type        = "NUMERIC"
      mode        = "REQUIRED"
      description = "Total claim amount"
    },
    {
      name        = "paid_amount"
      type        = "NUMERIC"
      mode        = "NULLABLE"
      description = "Amount paid"
    },
    {
      name        = "claim_status"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Claim status (approved, denied, pending)"
    },
    {
      name        = "diagnosis_codes"
      type        = "STRING"
      mode        = "REPEATED"
      description = "Associated diagnosis codes"
    },
    {
      name        = "procedure_codes"
      type        = "STRING"
      mode        = "REPEATED"
      description = "Procedure codes"
    }
  ])
  
  labels = merge(
    local.common_labels,
    {
      table_type   = "financial"
      contains_phi = "true"
      masked       = "true"
    }
  )
}

# ============================================================================
# AUTHORIZED VIEWS FOR DATA ACCESS CONTROL
# ============================================================================

resource "google_bigquery_table" "patients_analyst_view" {
  dataset_id          = google_bigquery_dataset.prod_healthcare_data.dataset_id
  table_id            = "patients_analyst_view"
  deletion_protection = false
  
  description = "De-identified patient view for analysts - no direct identifiers"
  
  view {
    query = <<-SQL
      SELECT
        patient_id,
        EXTRACT(YEAR FROM date_of_birth) AS birth_year,
        CASE
          WHEN DATE_DIFF(CURRENT_DATE(), date_of_birth, YEAR) > 90
          THEN '90+'
          ELSE CAST(FLOOR(DATE_DIFF(CURRENT_DATE(), date_of_birth, YEAR) / 5) * 5 AS STRING)
        END AS age_group,
        gender,
        SUBSTR(zip_code, 1, 3) AS zip_3digit,
        state,
        created_date
      FROM
        `${var.project_id}.${google_bigquery_dataset.prod_healthcare_data.dataset_id}.patients`
      WHERE
        masking_applied = TRUE
    SQL
    
    use_legacy_sql = false
  }
  
  labels = merge(
    local.common_labels,
    {
      view_type    = "authorized"
      access_level = "analyst"
      contains_phi = "false"
    }
  )
}

resource "google_bigquery_table" "encounters_aggregated_view" {
  dataset_id          = google_bigquery_dataset.prod_healthcare_data.dataset_id
  table_id            = "encounters_aggregated_view"
  deletion_protection = false
  
  description = "Aggregated encounter statistics for reporting"
  
  view {
    query = <<-SQL
      SELECT
        encounter_type,
        facility_id,
        EXTRACT(YEAR FROM encounter_date) AS encounter_year,
        EXTRACT(MONTH FROM encounter_date) AS encounter_month,
        COUNT(*) AS encounter_count,
        COUNT(DISTINCT patient_id) AS unique_patients,
        AVG(TIMESTAMP_DIFF(discharge_datetime, admission_datetime, HOUR)) AS avg_length_of_stay_hours
      FROM
        `${var.project_id}.${google_bigquery_dataset.prod_healthcare_data.dataset_id}.encounters`
      WHERE
        encounter_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR)
      GROUP BY
        encounter_type, facility_id, encounter_year, encounter_month
      HAVING
        encounter_count >= 11  -- K-anonymity threshold
    SQL
    
    use_legacy_sql = false
  }
  
  labels = merge(
    local.common_labels,
    {
      view_type    = "aggregated"
      access_level = "analyst"
      k_anonymity  = "11"
    }
  )
}

# ============================================================================
# ROW-LEVEL SECURITY POLICIES
# ============================================================================

resource "google_bigquery_datapolicy_data_policy" "patient_data_policy" {
  provider = google-beta
  
  location        = var.bigquery_dataset_location
  data_policy_id  = "patient_data_policy"
  policy_tag      = google_data_catalog_policy_tag.phi_tag.name
  data_policy_type = "DATA_MASKING_POLICY"
  
  data_masking_policy {
    predefined_expression = "SHA256"
  }
}

# ============================================================================
# MATERIALIZED VIEWS FOR PERFORMANCE
# ============================================================================

resource "google_bigquery_table" "patient_summary_mv" {
  dataset_id          = google_bigquery_dataset.prod_healthcare_data.dataset_id
  table_id            = "patient_summary_mv"
  deletion_protection = false
  
  description = "Materialized view of patient summaries for dashboard performance"
  
  materialized_view {
    query = <<-SQL
      SELECT
        patient_id,
        COUNT(DISTINCT e.encounter_id) AS total_encounters,
        COUNT(DISTINCT c.claim_id) AS total_claims,
        SUM(c.claim_amount) AS total_claim_amount,
        MAX(e.encounter_date) AS last_encounter_date,
        ARRAY_AGG(DISTINCT e.encounter_type IGNORE NULLS) AS encounter_types
      FROM
        `${var.project_id}.${google_bigquery_dataset.prod_healthcare_data.dataset_id}.patients` p
      LEFT JOIN
        `${var.project_id}.${google_bigquery_dataset.prod_healthcare_data.dataset_id}.encounters` e
        ON p.patient_id = e.patient_id
      LEFT JOIN
        `${var.project_id}.${google_bigquery_dataset.prod_healthcare_data.dataset_id}.claims` c
        ON p.patient_id = c.patient_id
      GROUP BY
        patient_id
    SQL
    
    enable_refresh = true
    refresh_interval_ms = 3600000  # 1 hour
  }
  
  labels = merge(
    local.common_labels,
    {
      view_type = "materialized"
      purpose   = "dashboard-performance"
    }
  )
}

# ============================================================================
# BI ENGINE RESERVATION
# ============================================================================

resource "google_bigquery_reservation" "bi_engine_reservation" {
  count = var.bigquery_slot_capacity > 0 ? 1 : 0
  
  name              = "healthcare-bi-engine"
  location          = var.bigquery_dataset_location
  slot_capacity     = 100
  edition           = "ENTERPRISE"
  ignore_idle_slots = false
  
  autoscale {
    max_slots = 200
  }
}

# ============================================================================
# DATA CATALOG POLICY TAGS
# ============================================================================

resource "google_data_catalog_taxonomy" "healthcare_taxonomy" {
  provider = google-beta
  
  region               = var.region
  display_name         = "Healthcare Data Classification"
  description          = "Data classification taxonomy for healthcare PHI/PII"
  activated_policy_types = ["FINE_GRAINED_ACCESS_CONTROL"]
}

resource "google_data_catalog_policy_tag" "phi_tag" {
  provider = google-beta
  
  taxonomy     = google_data_catalog_taxonomy.healthcare_taxonomy.id
  display_name = "PHI - Protected Health Information"
  description  = "Contains HIPAA-protected health information"
}

resource "google_data_catalog_policy_tag" "pii_tag" {
  provider = google-beta
  
  taxonomy     = google_data_catalog_taxonomy.healthcare_taxonomy.id
  display_name = "PII - Personally Identifiable Information"
  description  = "Contains personally identifiable information"
}

resource "google_data_catalog_policy_tag" "sensitive_tag" {
  provider = google-beta
  
  taxonomy     = google_data_catalog_taxonomy.healthcare_taxonomy.id
  display_name = "SENSITIVE - Business Sensitive"
  description  = "Contains business-sensitive information"
}

resource "google_data_catalog_policy_tag" "public_tag" {
  provider = google-beta
  
  taxonomy     = google_data_catalog_taxonomy.healthcare_taxonomy.id
  display_name = "PUBLIC - Public Data"
  description  = "Public or de-identified data"
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "bigquery_datasets" {
  description = "BigQuery dataset information"
  value = {
    prod_dataset_id   = google_bigquery_dataset.prod_healthcare_data.dataset_id
    prod_dataset_name = google_bigquery_dataset.prod_healthcare_data.friendly_name
    audit_dataset_id  = google_bigquery_dataset.audit_logs.dataset_id
    encryption_key    = google_kms_crypto_key.bigquery_key.id
  }
}

output "bigquery_tables" {
  description = "BigQuery table information"
  value = {
    patients_table    = google_bigquery_table.patients.table_id
    encounters_table  = google_bigquery_table.encounters.table_id
    claims_table      = google_bigquery_table.claims.table_id
    analyst_view      = google_bigquery_table.patients_analyst_view.table_id
  }
}

output "data_catalog_tags" {
  description = "Data Catalog policy tags"
  value = {
    taxonomy_id = google_data_catalog_taxonomy.healthcare_taxonomy.id
    phi_tag     = google_data_catalog_policy_tag.phi_tag.name
    pii_tag     = google_data_catalog_policy_tag.pii_tag.name
  }
}
