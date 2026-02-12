# Creates DLP inspection templates for PII/PHI detection

# DLP inspection template for PII/PHI
resource "google_data_loss_prevention_inspect_template" "pii_detection" {
  parent = "projects/${var.project_id}/locations/global"
  display_name = "Telecom PII Detection Template"
  description  = "Detects PHI/PII in Telecom data"
  
  inspect_config {
    # Standard info types for PII
    info_types {
      name = "US_SOCIAL_SECURITY_NUMBER"
    }
    info_types {
      name = "EMAIL_ADDRESS"
    }
    info_types {
      name = "PHONE_NUMBER"
    }
    info_types {
      name = "PERSON_NAME"
    }
    info_types {
      name = "DATE_OF_BIRTH"
    }
    info_types {
      name = "US_DRIVERS_LICENSE_NUMBER"
    }
    info_types {
      name = "MEDICAL_RECORD_NUMBER"
    }
    info_types {
      name = "US_Telecom_NPI"
    }
    
    # Custom regex patterns for Telecom data
    custom_info_types {
      name = "MEDICAL_RECORD_NUMBER"
      regex {
        pattern = "MRN[0-9]{8}"
      }
    }
    
    custom_info_types {
      name = "PATIENT_ID"
      regex {
        pattern = "PID[0-9]{10}"
      }
    }
    
    # Minimum likelihood threshold
    min_likelihood = "POSSIBLE"
    
    # Include quote in findings
    include_quote = true
    
    # Rule set for excluding certain fields
    rule_set {
      info_types {
        name = "PERSON_NAME"
      }
      rules {
        exclusion_rule {
          dictionary {
            word_list {
              words = ["Test", "TEST", "Unknown", "UNKNOWN"]
            }
          }
          matching_type = "MATCHING_TYPE_FULL_MATCH"
        }
      }
    }
  }
}

# DLP de-identification template
resource "google_data_loss_prevention_deidentify_template" "phi_masking" {
  parent = "projects/${var.project_id}/locations/global"
  display_name = "PHI Masking Template"
  description  = "Masks PHI/PII data"
  
  deidentify_config {
    # Record transformations
    record_transformations {
      field_transformations {
        fields {
          name = "ssn"
        }
        fields {
          name = "social_security_number"
        }
        primitive_transformation {
          crypto_replace_ffx_fpe_config {
            crypto_key {
              unwrapped {
                key = random_password.dlp_crypto_key.result
              }
            }
            common_algorithm = "FFX_COMMON_ALGORITHM_AES256"
            surrogate_info_type {
              name = "SSN_TOKEN"
            }
          }
        }
      }
      
      field_transformations {
        fields {
          name = "email"
        }
        primitive_transformation {
          replace_config {
            new_value {
              string_value = "[EMAIL REDACTED]"
            }
          }
        }
      }
      
      field_transformations {
        fields {
          name = "phone"
        }
        fields {
          name = "phone_number"
        }
        primitive_transformation {
          replace_config {
            new_value {
              string_value = "XXX-XXX-XXXX"
            }
          }
        }
      }
    }
  }
}

# Random key for DLP
resource "random_password" "dlp_crypto_key" {
  length  = 32
  special = false
}

# Output DLP template IDs
output "dlp_inspect_template_id" {
  value = google_data_loss_prevention_inspect_template.pii_detection.id
}
