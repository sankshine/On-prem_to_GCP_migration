# Creates VPC Service Controls perimeter for HIPAA compliance

# Access Context Manager policy (requires organization-level setup)
# NOTE: This requires an existing Access Policy. If you don't have one,
# you need to create it at the organization level first.

# VPC Service Controls perimeter
resource "google_access_context_manager_service_perimeter" "Telecom_perimeter" {
  count = var.enable_vpc_service_controls && var.access_policy_id != "" ? 1 : 0
  
  parent = "accessPolicies/${var.access_policy_id}"
  name   = "accessPolicies/${var.access_policy_id}/servicePerimeters/Telecom_data_perimeter"
  title  = "Telecom Data Perimeter"
  description = "VPC Service Controls perimeter for Telecom PHI data"
  
  status {
    # Resources (projects) inside the perimeter
    resources = ["projects/${var.project_number}"]
    
    # Restricted services
    restricted_services = [
      "bigquery.googleapis.com",
      "storage.googleapis.com",
      "dataflow.googleapis.com",
      "dlp.googleapis.com",
      "cloudkms.googleapis.com"
    ]
    
    # Access levels (who can access from outside)
    # This requires an access level to be defined
    access_levels = var.access_policy_id != "" ? [
      "accessPolicies/${var.access_policy_id}/accessLevels/corp_network"
    ] : []
    
    # VPC accessible services
    vpc_accessible_services {
      enable_restriction = true
      allowed_services = [
        "bigquery.googleapis.com",
        "storage.googleapis.com",
        "dataflow.googleapis.com"
      ]
    }
    
    # Methods that can be called from outside
    ingress_policies {
      ingress_from {
        sources {
          access_level = "accessPolicies/${var.access_policy_id}/accessLevels/corp_network"
        }
        identity_type = "ANY_IDENTITY"
      }
      ingress_to {
        operations {
          service_name = "storage.googleapis.com"
          method_selectors {
            method = "google.storage.objects.get"
          }
          method_selectors {
            method = "google.storage.objects.list"
          }
        }
        resources = ["projects/${var.project_number}"]
      }
    }
    
    # Egress rules
    egress_policies {
      egress_from {
        identity_type = "ANY_IDENTITY"
      }
      egress_to {
        operations {
          service_name = "bigquery.googleapis.com"
        }
        resources = ["projects/${var.project_number}"]
      }
    }
  }
  
  use_explicit_dry_run_spec = false
}

# Bridge perimeter for allowed services
resource "google_access_context_manager_service_perimeter" "Telecom_bridge" {
  count = var.enable_vpc_service_controls && var.access_policy_id != "" ? 1 : 0
  
  parent = "accessPolicies/${var.access_policy_id}"
  name   = "accessPolicies/${var.access_policy_id}/servicePerimeters/Telecom_bridge"
  title  = "Telecom Bridge Perimeter"
  perimeter_type = "PERIMETER_TYPE_REGULAR"
  
  status {
    resources = ["projects/${var.project_number}"]
    restricted_services = [
      "bigquery.googleapis.com",
      "storage.googleapis.com"
    ]
  }
}

# Output
output "vpc_sc_perimeter_name" {
  value = var.enable_vpc_service_controls && var.access_policy_id != "" ? google_access_context_manager_service_perimeter.Telecom_perimeter[0].name : "Not enabled"
}F
