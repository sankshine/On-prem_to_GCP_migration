# Main Terraform Configuration
# Healthcare Data Migration: Hadoop to BigQuery

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
  
  backend "gcs" {
    bucket = "healthcare-terraform-state"
    prefix = "migration/state"
  }
}

# Configure Google Provider
provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# Enable Required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "bigquery.googleapis.com",
    "storage-api.googleapis.com",
    "dataflow.googleapis.com",
    "dlp.googleapis.com",
    "cloudkms.googleapis.com",
    "iam.googleapis.com",
    "compute.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "cloudbuild.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "accesscontextmanager.googleapis.com",
    "servicenetworking.googleapis.com"
  ])
  
  project = var.project_id
  service = each.key
  
  disable_on_destroy = false
  
  timeouts {
    create = "30m"
    update = "40m"
  }
}

# Random suffix for unique resource names
resource "random_id" "suffix" {
  byte_length = 4
}

# Local variables
locals {
  common_labels = {
    environment = var.environment
    project     = "healthcare-migration"
    managed_by  = "terraform"
    compliance  = "hipaa"
    cost_center = var.cost_center
  }
  
  resource_suffix = "${var.environment}-${random_id.suffix.hex}"
  
  # Data sensitivity levels
  sensitivity_labels = {
    high   = "Contains PHI/PII data"
    medium = "Contains business-critical data"
    low    = "Public or non-sensitive data"
  }
}

# Create VPC Network
resource "google_compute_network" "vpc_network" {
  name                    = "healthcare-migration-vpc-${local.resource_suffix}"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  
  depends_on = [google_project_service.required_apis]
}

# Subnets
resource "google_compute_subnetwork" "dataflow_subnet" {
  name          = "dataflow-subnet-${local.resource_suffix}"
  ip_cidr_range = var.dataflow_subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc_network.id
  
  private_ip_google_access = true
  
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
  
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pod_cidr_range
  }
  
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.service_cidr_range
  }
}

resource "google_compute_subnetwork" "management_subnet" {
  name          = "management-subnet-${local.resource_suffix}"
  ip_cidr_range = var.management_subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc_network.id
  
  private_ip_google_access = true
}

# Cloud Router for Cloud NAT
resource "google_compute_router" "router" {
  name    = "healthcare-router-${local.resource_suffix}"
  region  = var.region
  network = google_compute_network.vpc_network.id
  
  bgp {
    asn = 64514
  }
}

# Cloud NAT for private instance internet access
resource "google_compute_router_nat" "nat" {
  name                               = "healthcare-nat-${local.resource_suffix}"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Firewall Rules
resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal-${local.resource_suffix}"
  network = google_compute_network.vpc_network.name
  
  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  
  allow {
    protocol = "icmp"
  }
  
  source_ranges = [
    var.dataflow_subnet_cidr,
    var.management_subnet_cidr
  ]
  
  priority = 1000
}

resource "google_compute_firewall" "allow_healthchecks" {
  name    = "allow-healthchecks-${local.resource_suffix}"
  network = google_compute_network.vpc_network.name
  
  allow {
    protocol = "tcp"
  }
  
  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16"
  ]
  
  target_tags = ["allow-health-check"]
  priority    = 1000
}

resource "google_compute_firewall" "allow_dataflow_workers" {
  name    = "allow-dataflow-workers-${local.resource_suffix}"
  network = google_compute_network.vpc_network.name
  
  allow {
    protocol = "tcp"
    ports    = ["12345-12346"]
  }
  
  source_tags = ["dataflow"]
  target_tags = ["dataflow"]
  priority    = 1000
}

resource "google_compute_firewall" "deny_all_ingress" {
  name     = "deny-all-ingress-${local.resource_suffix}"
  network  = google_compute_network.vpc_network.name
  priority = 65534
  
  deny {
    protocol = "all"
  }
  
  source_ranges = ["0.0.0.0/0"]
  
  description = "Default deny rule for unmatched traffic"
}

# VPC Peering for Private Service Access (Cloud SQL, etc.)
resource "google_compute_global_address" "private_ip_alloc" {
  name          = "private-ip-alloc-${local.resource_suffix}"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc_network.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc_network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name]
  
  depends_on = [google_project_service.required_apis]
}

# Monitoring and Logging Configuration
resource "google_monitoring_notification_channel" "email" {
  display_name = "Healthcare Migration Email Alerts"
  type         = "email"
  
  labels = {
    email_address = var.alert_email
  }
  
  enabled = true
}

resource "google_monitoring_notification_channel" "pagerduty" {
  count = var.enable_pagerduty ? 1 : 0
  
  display_name = "Healthcare Migration PagerDuty"
  type         = "pagerduty"
  
  labels = {
    service_key = var.pagerduty_service_key
  }
  
  sensitive_labels {
    auth_token = var.pagerduty_auth_token
  }
  
  enabled = true
}

# Log Router Sink for Long-term Storage
resource "google_logging_project_sink" "bigquery_sink" {
  name        = "bigquery-audit-sink-${local.resource_suffix}"
  destination = "bigquery.googleapis.com/projects/${var.project_id}/datasets/${google_bigquery_dataset.audit_logs.dataset_id}"
  
  filter = <<-EOT
    protoPayload.serviceName="bigquery.googleapis.com" OR
    protoPayload.serviceName="storage.googleapis.com" OR
    protoPayload.serviceName="dlp.googleapis.com" OR
    protoPayload.serviceName="dataflow.googleapis.com"
  EOT
  
  unique_writer_identity = true
  
  bigquery_options {
    use_partitioned_tables = true
  }
  
  depends_on = [
    google_bigquery_dataset.audit_logs
  ]
}

# Grant writer access to log sink service account
resource "google_project_iam_member" "log_sink_writer" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = google_logging_project_sink.bigquery_sink.writer_identity
}

# Audit Logging Configuration
resource "google_project_iam_audit_config" "audit_config" {
  project = var.project_id
  service = "allServices"
  
  audit_log_config {
    log_type = "ADMIN_READ"
  }
  
  audit_log_config {
    log_type = "DATA_READ"
  }
  
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

# Secret Manager for Sensitive Configuration
resource "google_secret_manager_secret" "hadoop_credentials" {
  secret_id = "hadoop-credentials-${local.resource_suffix}"
  
  labels = merge(
    local.common_labels,
    {
      sensitivity = "high"
    }
  )
  
  replication {
    auto {}
  }
  
  depends_on = [google_project_service.required_apis]
}

resource "google_secret_manager_secret" "collibra_api_key" {
  secret_id = "collibra-api-key-${local.resource_suffix}"
  
  labels = merge(
    local.common_labels,
    {
      sensitivity = "high"
    }
  )
  
  replication {
    auto {}
  }
  
  depends_on = [google_project_service.required_apis]
}

# Budget Alert
resource "google_billing_budget" "migration_budget" {
  billing_account = var.billing_account_id
  display_name    = "Healthcare Migration Budget"
  
  budget_filter {
    projects = ["projects/${var.project_id}"]
    
    labels = {
      environment = var.environment
      project     = "healthcare-migration"
    }
  }
  
  amount {
    specified_amount {
      currency_code = "USD"
      units         = var.monthly_budget_amount
    }
  }
  
  threshold_rules {
    threshold_percent = 0.5
    spend_basis       = "CURRENT_SPEND"
  }
  
  threshold_rules {
    threshold_percent = 0.75
    spend_basis       = "CURRENT_SPEND"
  }
  
  threshold_rules {
    threshold_percent = 0.9
    spend_basis       = "CURRENT_SPEND"
  }
  
  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "CURRENT_SPEND"
  }
  
  all_updates_rule {
    monitoring_notification_channels = [
      google_monitoring_notification_channel.email.id
    ]
    
    disable_default_iam_recipients = false
  }
}

# Output important resource information
output "network_info" {
  description = "VPC Network information"
  value = {
    network_name          = google_compute_network.vpc_network.name
    network_id            = google_compute_network.vpc_network.id
    dataflow_subnet_name  = google_compute_subnetwork.dataflow_subnet.name
    management_subnet_name = google_compute_subnetwork.management_subnet.name
  }
}

output "notification_channels" {
  description = "Monitoring notification channel IDs"
  value = {
    email     = google_monitoring_notification_channel.email.id
    pagerduty = var.enable_pagerduty ? google_monitoring_notification_channel.pagerduty[0].id : null
  }
}

output "log_sink" {
  description = "Log sink information"
  value = {
    sink_name       = google_logging_project_sink.bigquery_sink.name
    destination     = google_logging_project_sink.bigquery_sink.destination
    writer_identity = google_logging_project_sink.bigquery_sink.writer_identity
  }
}

output "project_info" {
  description = "Project configuration"
  value = {
    project_id     = var.project_id
    region         = var.region
    environment    = var.environment
    resource_suffix = local.resource_suffix
  }
}
