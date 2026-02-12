# Security Controls Documentation

## Table of Contents
1. [Security Framework Overview](#security-framework-overview)
2. [Identity and Access Management (IAM)](#identity-and-access-management-iam)
3. [Data Encryption](#data-encryption)
4. [PII/PHI Detection and Masking](#piiphi-detection-and-masking)
5. [Network Security](#network-security)
6. [Audit and Compliance](#audit-and-compliance)
7. [Incident Response](#incident-response)
8. [Security Testing](#security-testing)

---

## Security Framework Overview

### Security Objectives

The migration implements a comprehensive security framework aligned with:

- **HIPAA Security Rule** (45 CFR Part 164, Subpart C)
- **NIST Cybersecurity Framework**
- **CIS Google Cloud Platform Benchmarks**
- **ISO 27001 Standards**

### Security Principles

1. **Zero Trust Architecture**: Never trust, always verify
2. **Least Privilege Access**: Minimum permissions required
3. **Defense in Depth**: Multiple security layers
4. **Data-Centric Security**: Protect data regardless of location
5. **Continuous Monitoring**: Real-time threat detection

---

## Identity and Access Management (IAM)

### IAM Hierarchy

```
Organization
└── healthcare-corp.com
    ├── Folder: Production
    │   └── Project: prod-healthcare-migration
    │       ├── BigQuery Datasets
    │       ├── Cloud Storage Buckets
    │       ├── Dataflow Jobs
    │       └── DLP Resources
    └── Folder: Development
        └── Project: dev-healthcare-migration
```

### Custom IAM Roles

#### 1. Healthcare Data Engineer Role

```yaml
title: "Healthcare Data Engineer"
description: "Manages data pipelines with PII/PHI access controls"
stage: "GA"
includedPermissions:
  # BigQuery Permissions
  - bigquery.datasets.get
  - bigquery.tables.create
  - bigquery.tables.get
  - bigquery.tables.getData
  - bigquery.tables.list
  - bigquery.tables.update
  - bigquery.jobs.create
  - bigquery.jobs.get
  
  # Cloud Storage Permissions
  - storage.buckets.get
  - storage.objects.create
  - storage.objects.delete
  - storage.objects.get
  - storage.objects.list
  
  # Dataflow Permissions
  - dataflow.jobs.create
  - dataflow.jobs.get
  - dataflow.jobs.list
  - dataflow.jobs.cancel
  
  # DLP Permissions
  - dlp.deidentifyTemplates.get
  - dlp.inspectTemplates.get
  - dlp.jobs.create
  - dlp.jobs.get
  
  # Logging Permissions (read-only)
  - logging.logEntries.list
  - logging.logs.list

excludedPermissions:
  - bigquery.datasets.delete  # Prevent accidental deletion
  - bigquery.tables.delete
```

#### 2. Healthcare Data Analyst Role

```yaml
title: "Healthcare Data Analyst"
description: "Read-only access to de-identified data"
stage: "GA"
includedPermissions:
  # BigQuery Permissions (Read-Only)
  - bigquery.datasets.get
  - bigquery.tables.get
  - bigquery.tables.list
  - bigquery.jobs.create  # Required for queries
  - bigquery.jobs.get
  
  # Authorized Views Only
  - bigquery.rowAccessPolicies.list
  
  # No direct table data access
  # Access granted through authorized views only

conditions:
  # Only allow access during business hours
  - expression: "request.time.getHours('America/New_York') >= 8 && request.time.getHours('America/New_York') <= 18"
    title: "Business Hours Only"
```

#### 3. Security Auditor Role

```yaml
title: "Healthcare Security Auditor"
description: "Audit log access without data modification"
stage: "GA"
includedPermissions:
  # Audit Log Permissions
  - logging.logEntries.list
  - logging.logs.list
  - logging.privateLogEntries.list
  
  # IAM Permissions (Read-Only)
  - iam.roles.get
  - iam.roles.list
  - iam.serviceAccounts.get
  - iam.serviceAccounts.list
  
  # Security Command Center
  - securitycenter.findings.list
  - securitycenter.findings.get
  - securitycenter.assets.list
  
  # DLP Job Monitoring
  - dlp.jobs.get
  - dlp.jobs.list
```

### Service Account Strategy

| Service Account | Purpose | Permissions | Key Rotation |
|-----------------|---------|-------------|--------------|
| `sa-dataflow-extraction@` | Hadoop extraction pipeline | Read HDFS, Write GCS | 90 days |
| `sa-dataflow-transform@` | Data transformation pipeline | Read/Write GCS, DLP API | 90 days |
| `sa-dataflow-load@` | BigQuery loading pipeline | Read GCS, Write BigQuery | 90 days |
| `sa-dlp-inspector@` | PII/PHI detection jobs | DLP API, Read GCS | 90 days |
| `sa-collibra-sync@` | Metadata synchronization | Read BigQuery metadata | 90 days |
| `sa-monitoring@` | Monitoring and alerting | Logging, Monitoring APIs | 90 days |

### Workload Identity Federation

```hcl
# Terraform configuration for Workload Identity
resource "google_service_account" "dataflow_sa" {
  account_id   = "sa-dataflow-extraction"
  display_name = "Dataflow Extraction Service Account"
  project      = var.project_id
}

resource "google_project_iam_member" "dataflow_workload_identity" {
  project = var.project_id
  role    = "roles/iam.workloadIdentityUser"
  member  = "serviceAccount:${var.project_id}.svc.id.goog[dataflow/dataflow-sa]"
}

resource "google_service_account_iam_binding" "dataflow_sa_binding" {
  service_account_id = google_service_account.dataflow_sa.name
  role               = "roles/iam.workloadIdentityUser"
  
  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[dataflow/dataflow-extraction]",
  ]
}
```

### Access Control Matrix

| Role | BigQuery Read | BigQuery Write | GCS Read | GCS Write | DLP API | Prod Access |
|------|--------------|----------------|----------|-----------|---------|-------------|
| **Data Engineer** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Data Analyst** | ✅ (Views) | ❌ | ❌ | ❌ | ❌ | ✅ (Views) |
| **Data Scientist** | ✅ (Views) | ❌ | ❌ | ❌ | ❌ | ✅ (Views) |
| **Security Auditor** | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ (Logs) |
| **DevOps** | ❌ | ❌ | ✅ (Logs) | ❌ | ❌ | ✅ (Infra) |
| **Compliance Officer** | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ (Logs) |

---

## Data Encryption

### Encryption at Rest

#### Customer-Managed Encryption Keys (CMEK)

```hcl
# KMS Key Ring for BigQuery
resource "google_kms_key_ring" "bigquery_keyring" {
  name     = "bigquery-healthcare-keyring"
  location = "us-central1"
  project  = var.project_id
}

# Encryption Key for BigQuery
resource "google_kms_crypto_key" "bigquery_key" {
  name            = "bigquery-healthcare-key"
  key_ring        = google_kms_key_ring.bigquery_keyring.id
  rotation_period = "7776000s"  # 90 days
  
  lifecycle {
    prevent_destroy = true
  }
  
  version_template {
    algorithm = "GOOGLE_SYMMETRIC_ENCRYPTION"
  }
}

# Grant BigQuery Service Account access to KMS key
resource "google_kms_crypto_key_iam_binding" "bigquery_key_binding" {
  crypto_key_id = google_kms_crypto_key.bigquery_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  
  members = [
    "serviceAccount:bq-${var.project_number}@bigquery-encryption.iam.gserviceaccount.com",
  ]
}

# Apply CMEK to BigQuery Dataset
resource "google_bigquery_dataset" "healthcare_dataset" {
  dataset_id = "prod_healthcare_data"
  location   = "US"
  
  default_encryption_configuration {
    kms_key_name = google_kms_crypto_key.bigquery_key.id
  }
  
  access {
    role          = "OWNER"
    user_by_email = google_service_account.dataflow_sa.email
  }
  
  labels = {
    environment = "production"
    compliance  = "hipaa"
  }
}
```

#### Key Management Policies

```yaml
# Key Rotation Policy
rotation_schedule: "90 days"
automated_rotation: true
rotation_notification:
  - security-team@healthcare-corp.com
  - compliance@healthcare-corp.com

# Key Access Logging
audit_logging:
  enabled: true
  log_types:
    - ADMIN_READ
    - DATA_READ
    - DATA_WRITE
  retention_days: 2555  # 7 years for HIPAA

# Key Version Management
minimum_versions: 3
automatic_version_destruction: false  # Manual review required
destruction_delay: "30 days"
```

### Encryption in Transit

#### TLS Configuration

```yaml
# TLS Policy for all GCP services
tls_policy:
  minimum_version: "TLS 1.3"
  cipher_suites:
    - "TLS_AES_256_GCM_SHA384"
    - "TLS_AES_128_GCM_SHA256"
    - "TLS_CHACHA20_POLY1305_SHA256"
  
  # Disable weak protocols
  disabled_versions:
    - "TLS 1.0"
    - "TLS 1.1"
    - "TLS 1.2"  # Only for legacy systems
  
  # Certificate configuration
  certificate_authority: "Google Trust Services"
  certificate_validity: "90 days"
  certificate_renewal: "automatic"
  
  # HSTS (HTTP Strict Transport Security)
  hsts_enabled: true
  hsts_max_age: "31536000"  # 1 year
  hsts_include_subdomains: true
  hsts_preload: true
```

#### VPN Configuration

```bash
# HA VPN Configuration
gcloud compute vpn-tunnels create tunnel-to-onprem-1 \
  --peer-gcp-gateway=onprem-gateway \
  --region=us-central1 \
  --ike-version=2 \
  --shared-secret=$SHARED_SECRET \
  --router=healthcare-router \
  --vpn-gateway=healthcare-ha-vpn-gateway \
  --interface=0

# IPSec Configuration
IKE_ENCRYPTION: AES-256-GCM
IKE_INTEGRITY: SHA2-384
IKE_DH_GROUP: 20 (384-bit ECC)
ESP_ENCRYPTION: AES-256-GCM
ESP_INTEGRITY: SHA2-384
PFS_GROUP: 20 (384-bit ECC)
LIFETIME: 3600 seconds
```

### Field-Level Encryption

#### Application-Layer Encryption

```python
from google.cloud import kms
from cryptography.fernet import Fernet
import base64

class FieldEncryption:
    """Field-level encryption for sensitive data"""
    
    def __init__(self, project_id, location, key_ring, key_name):
        self.kms_client = kms.KeyManagementServiceClient()
        self.key_name = (
            f"projects/{project_id}/locations/{location}/"
            f"keyRings/{key_ring}/cryptoKeys/{key_name}"
        )
    
    def encrypt_field(self, plaintext: str) -> str:
        """Encrypt a field using Cloud KMS"""
        plaintext_bytes = plaintext.encode('utf-8')
        
        # Encrypt with Cloud KMS
        response = self.kms_client.encrypt(
            request={
                'name': self.key_name,
                'plaintext': plaintext_bytes
            }
        )
        
        # Return base64-encoded ciphertext
        return base64.b64encode(response.ciphertext).decode('utf-8')
    
    def decrypt_field(self, ciphertext: str) -> str:
        """Decrypt a field using Cloud KMS"""
        ciphertext_bytes = base64.b64decode(ciphertext.encode('utf-8'))
        
        # Decrypt with Cloud KMS
        response = self.kms_client.decrypt(
            request={
                'name': self.key_name,
                'ciphertext': ciphertext_bytes
            }
        )
        
        return response.plaintext.decode('utf-8')

# Example usage for address encryption
encryptor = FieldEncryption(
    project_id='prod-healthcare-migration',
    location='us-central1',
    key_ring='bigquery-healthcare-keyring',
    key_name='field-encryption-key'
)

# Encrypt sensitive address field
encrypted_address = encryptor.encrypt_field("123 Main Street, New York, NY 10001")
# Store: "Q3J5cHRvZ3JhcGhpY0VuY3J5cHRlZERhdGE="
```

---

## PII/PHI Detection and Masking

### Cloud DLP Configuration

#### PII Detection Templates

```json
{
  "name": "projects/prod-healthcare-migration/locations/global/inspectTemplates/pii-detection-template",
  "displayName": "Comprehensive PII Detection",
  "description": "Detects all PII types for healthcare data",
  "inspectConfig": {
    "infoTypes": [
      {"name": "US_SOCIAL_SECURITY_NUMBER"},
      {"name": "EMAIL_ADDRESS"},
      {"name": "PHONE_NUMBER"},
      {"name": "PERSON_NAME"},
      {"name": "DATE_OF_BIRTH"},
      {"name": "US_DRIVERS_LICENSE_NUMBER"},
      {"name": "CREDIT_CARD_NUMBER"},
      {"name": "US_BANK_ROUTING_MICR"},
      {"name": "IP_ADDRESS"},
      {"name": "MAC_ADDRESS"},
      {"name": "IMEI_HARDWARE_ID"},
      {"name": "LOCATION"},
      {"name": "US_HEALTHCARE_NPI"},
      {"name": "MEDICAL_RECORD_NUMBER"}
    ],
    "minLikelihood": "POSSIBLE",
    "limits": {
      "maxFindingsPerItem": 0,
      "maxFindingsPerRequest": 0
    },
    "includeQuote": true,
    "customInfoTypes": [
      {
        "infoType": {"name": "MEDICAL_RECORD_NUMBER"},
        "regex": {"pattern": "MRN[0-9]{8}"},
        "likelihood": "VERY_LIKELY"
      },
      {
        "infoType": {"name": "PATIENT_ID"},
        "regex": {"pattern": "PID[0-9]{10}"},
        "likelihood": "VERY_LIKELY"
      }
    ]
  }
}
```

#### PHI Detection Templates

```json
{
  "name": "projects/prod-healthcare-migration/locations/global/inspectTemplates/phi-detection-template",
  "displayName": "HIPAA PHI Detection",
  "description": "Detects Protected Health Information per HIPAA",
  "inspectConfig": {
    "infoTypes": [
      {"name": "PERSON_NAME"},
      {"name": "DATE"},
      {"name": "PHONE_NUMBER"},
      {"name": "FAX_NUMBER"},
      {"name": "EMAIL_ADDRESS"},
      {"name": "US_SOCIAL_SECURITY_NUMBER"},
      {"name": "MEDICAL_RECORD_NUMBER"},
      {"name": "HEALTH_PLAN_BENEFICIARY_NUMBER"},
      {"name": "ACCOUNT_NUMBER"},
      {"name": "CERTIFICATE_LICENSE_NUMBER"},
      {"name": "VEHICLE_IDENTIFICATION_NUMBER"},
      {"name": "DEVICE_ID"},
      {"name": "IP_ADDRESS"},
      {"name": "BIOMETRIC_DATA"},
      {"name": "PHOTO"},
      {"name": "US_HEALTHCARE_NPI"}
    ],
    "customInfoTypes": [
      {
        "infoType": {"name": "CLINICAL_NOTE"},
        "dictionary": {
          "wordList": {
            "words": [
              "diagnosis", "treatment", "medication", "symptom",
              "procedure", "prescription", "surgery", "therapy"
            ]
          }
        }
      }
    ],
    "ruleSet": [
      {
        "infoTypes": [{"name": "PERSON_NAME"}],
        "rules": [
          {
            "hotwordRule": {
              "hotwordRegex": {"pattern": "patient|provider|doctor"},
              "proximity": {"windowBefore": 50, "windowAfter": 50},
              "likelihoodAdjustment": {"fixedLikelihood": "VERY_LIKELY"}
            }
          }
        ]
      }
    ]
  }
}
```

### De-identification Strategies

#### 1. Tokenization (Format-Preserving)

```python
from google.cloud import dlp_v2

def tokenize_ssn(project_id, ssn):
    """Tokenize SSN using format-preserving encryption"""
    dlp = dlp_v2.DlpServiceClient()
    
    # Crypto key configuration
    crypto_key_name = (
        f"projects/{project_id}/locations/global/"
        f"keyRings/dlp-keyring/cryptoKeys/tokenization-key"
    )
    
    # Format-preserving encryption for SSN
    crypto_replace_config = {
        'crypto_key': {
            'kms_wrapped': {
                'wrapped_key': get_wrapped_key(),
                'crypto_key_name': crypto_key_name
            }
        },
        'surrogate_info_type': {'name': 'SSN_TOKEN'}
    }
    
    # Apply transformation
    response = dlp.deidentify_content(
        request={
            'parent': f'projects/{project_id}',
            'deidentify_config': {
                'info_type_transformations': {
                    'transformations': [{
                        'info_types': [{'name': 'US_SOCIAL_SECURITY_NUMBER'}],
                        'primitive_transformation': {
                            'crypto_replace_ffx_fpe_config': crypto_replace_config
                        }
                    }]
                }
            },
            'item': {'value': ssn}
        }
    )
    
    return response.item.value

# Example:
# Input:  "123-45-6789"
# Output: "847-92-3156" (format preserved, reversible with key)
```

#### 2. Pseudonymization

```python
import hashlib
import hmac

def pseudonymize_name(name, secret_key):
    """Create deterministic pseudonym for name"""
    # HMAC-SHA256 for consistent pseudonyms
    hmac_obj = hmac.new(
        secret_key.encode('utf-8'),
        name.encode('utf-8'),
        hashlib.sha256
    )
    hash_value = hmac_obj.hexdigest()[:8]
    
    return f"PATIENT_{hash_value.upper()}"

# Example:
# Input:  "John Doe"
# Output: "PATIENT_A7B3C9D2"
# Same input always produces same pseudonym
```

#### 3. Date Shifting

```python
from datetime import datetime, timedelta
import random

def shift_date(date_string, patient_id, shift_range=365):
    """Shift dates consistently per patient"""
    # Use patient ID as seed for consistent shifting
    random.seed(patient_id)
    
    # Random shift within range
    shift_days = random.randint(-shift_range, shift_range)
    
    # Parse and shift date
    original_date = datetime.strptime(date_string, '%Y-%m-%d')
    shifted_date = original_date + timedelta(days=shift_days)
    
    return shifted_date.strftime('%Y-%m-%d')

# Example:
# Input:  "1985-06-15", patient_id="12345"
# Output: "1985-09-22" (consistent shift for this patient)
```

#### 4. Redaction

```python
def redact_email(email):
    """Redact email while preserving domain"""
    username, domain = email.split('@')
    
    # Keep first character of username
    if len(username) > 1:
        redacted_username = username[0] + '*' * (len(username) - 1)
    else:
        redacted_username = '*'
    
    return f"{redacted_username}@{domain}"

# Example:
# Input:  "john.doe@example.com"
# Output: "j*******@example.com"
```

### Masking Configuration Matrix

| Data Type | Detection Method | Masking Method | Reversible | Format Preserved |
|-----------|-----------------|----------------|------------|------------------|
| **SSN** | Regex + DLP | Tokenization (FFX) | ✅ (with key) | ✅ |
| **Names** | NLP + DLP | Pseudonymization | ❌ | ❌ |
| **Email** | Regex | Redaction | ❌ | ✅ (domain) |
| **Phone** | Regex + DLP | Partial Redaction | ❌ | ✅ |
| **DOB** | Date detection | Date Shifting | ❌ | ✅ |
| **Address** | NLP + DLP | Zip Code Only | ❌ | ❌ |
| **MRN** | Custom Regex | Tokenization | ✅ (with key) | ✅ |
| **Credit Card** | Luhn + DLP | Tokenization | ✅ (with key) | ✅ |
| **IP Address** | Regex | Hashing | ❌ | ❌ |
| **Clinical Notes** | NLP | Redaction | ❌ | ❌ |

---

## Network Security

### VPC Service Controls

```hcl
# Service Perimeter for Healthcare Data
resource "google_access_context_manager_service_perimeter" "healthcare_perimeter" {
  parent = "accessPolicies/${var.access_policy_id}"
  name   = "accessPolicies/${var.access_policy_id}/servicePerimeters/healthcare_perimeter"
  title  = "Healthcare Data Perimeter"
  
  status {
    restricted_services = [
      "bigquery.googleapis.com",
      "storage.googleapis.com",
      "dlp.googleapis.com",
      "dataflow.googleapis.com"
    ]
    
    resources = [
      "projects/${var.project_number}"
    ]
    
    # Ingress policies
    ingress_policies {
      ingress_from {
        sources {
          access_level = google_access_context_manager_access_level.onprem_access.name
        }
        identity_type = "ANY_IDENTITY"
      }
      ingress_to {
        resources = ["*"]
        operations {
          service_name = "bigquery.googleapis.com"
          method_selectors {
            method = "BigQueryStorage.ReadRows"
          }
        }
      }
    }
    
    # Egress policies
    egress_policies {
      egress_from {
        identity_type = "ANY_SERVICE_ACCOUNT"
      }
      egress_to {
        resources = ["*"]
        operations {
          service_name = "storage.googleapis.com"
          method_selectors {
            method = "*"
          }
        }
      }
    }
  }
}

# Access Level for On-Premises
resource "google_access_context_manager_access_level" "onprem_access" {
  parent = "accessPolicies/${var.access_policy_id}"
  name   = "accessPolicies/${var.access_policy_id}/accessLevels/onprem_access"
  title  = "On-Premises Access"
  
  basic {
    conditions {
      ip_subnetworks = [
        "10.0.0.0/8"  # On-prem network
      ]
    }
  }
}
```

### Firewall Rules

```hcl
# Allow only necessary traffic
resource "google_compute_firewall" "allow_dataflow_internal" {
  name    = "allow-dataflow-internal"
  network = google_compute_network.vpc_network.name
  
  allow {
    protocol = "tcp"
    ports    = ["12345-12346"]  # Dataflow worker communication
  }
  
  source_ranges = ["172.16.1.0/24"]  # Dataflow subnet
  target_tags   = ["dataflow-worker"]
}

resource "google_compute_firewall" "deny_all_ingress" {
  name     = "deny-all-ingress"
  network  = google_compute_network.vpc_network.name
  priority = 65534
  
  deny {
    protocol = "all"
  }
  
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_healthchecks" {
  name    = "allow-healthchecks"
  network = google_compute_network.vpc_network.name
  
  allow {
    protocol = "tcp"
  }
  
  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16"
  ]
}
```

---

## Audit and Compliance

### Audit Logging Configuration

```hcl
# Enable all audit logs
resource "google_project_iam_audit_config" "project_audit" {
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

# BigQuery specific audit logs
resource "google_project_iam_audit_config" "bigquery_audit" {
  project = var.project_id
  service = "bigquery.googleapis.com"
  
  audit_log_config {
    log_type = "ADMIN_READ"
  }
  
  audit_log_config {
    log_type = "DATA_READ"
    exempted_members = [
      "serviceAccount:${google_service_account.monitoring_sa.email}"
    ]
  }
  
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

# Log sink for long-term storage
resource "google_logging_project_sink" "audit_log_sink" {
  name        = "audit-log-sink"
  destination = "bigquery.googleapis.com/projects/${var.project_id}/datasets/audit_logs"
  filter      = <<-EOT
    protoPayload.serviceName="bigquery.googleapis.com" OR
    protoPayload.serviceName="storage.googleapis.com" OR
    protoPayload.serviceName="dlp.googleapis.com"
    severity >= INFO
  EOT
  
  unique_writer_identity = true
  
  bigquery_options {
    use_partitioned_tables = true
  }
}
```

### Compliance Monitoring

```sql
-- Query to detect unauthorized access attempts
SELECT
  timestamp,
  protoPayload.authenticationInfo.principalEmail as user_email,
  protoPayload.resourceName as resource,
  protoPayload.status.code as status_code,
  protoPayload.status.message as status_message
FROM
  `project.audit_logs.cloudaudit_googleapis_com_data_access`
WHERE
  protoPayload.status.code != 0  -- Failed access
  AND DATE(timestamp) = CURRENT_DATE()
ORDER BY
  timestamp DESC
LIMIT 100;

-- Query to track PHI data access
SELECT
  timestamp,
  protoPayload.authenticationInfo.principalEmail as user,
  protopayload.resourceName as table_accessed,
  protoPayload.methodName as operation,
  COUNT(*) as access_count
FROM
  `project.audit_logs.cloudaudit_googleapis_com_data_access`
WHERE
  protoPayload.resourceName LIKE '%patient%'
  OR protoPayload.resourceName LIKE '%claims%'
GROUP BY 1, 2, 3, 4
HAVING access_count > 100  -- Suspicious high volume
ORDER BY access_count DESC;
```

### HIPAA Compliance Controls

| Control | Implementation | Validation |
|---------|---------------|------------|
| **Access Control (164.308(a)(4))** | IAM roles, MFA | Quarterly access reviews |
| **Audit Controls (164.312(b))** | Cloud Audit Logs | Real-time monitoring |
| **Integrity (164.312(c)(1))** | Checksums, validation | Per-pipeline validation |
| **Authentication (164.312(d))** | IAM, Workload Identity | Annual penetration testing |
| **Transmission Security (164.312(e)(1))** | TLS 1.3, VPN | Quarterly vulnerability scans |
| **Encryption (164.312(a)(2)(iv))** | CMEK, Field encryption | Annual encryption audit |

---

## Incident Response

### Incident Classification

| Severity | Definition | Response Time | Escalation |
|----------|-----------|---------------|------------|
| **P0 - Critical** | PHI data breach, system compromise | 15 minutes | CISO, Legal |
| **P1 - High** | Unauthorized access, service outage | 1 hour | Security Manager |
| **P2 - Medium** | Failed compliance check, suspicious activity | 4 hours | Security Team |
| **P3 - Low** | Policy violation, minor security event | 24 hours | Team Lead |

### Incident Response Playbook

```markdown
## P0 Incident: PHI Data Breach

### Immediate Actions (0-30 minutes)
1. **Contain**: Revoke compromised credentials, disable affected resources
2. **Assess**: Determine scope of data exposure
3. **Notify**: Alert CISO, Legal, Compliance teams
4. **Document**: Begin incident log in ticketing system

### Investigation (30 minutes - 4 hours)
5. **Analyze Logs**: Review Cloud Audit Logs for unauthorized access
6. **Identify Root Cause**: Determine how breach occurred
7. **Affected Data**: List specific PHI records exposed
8. **Timeline**: Create detailed timeline of events

### Remediation (4-24 hours)
9. **Patch Vulnerability**: Fix security gap that enabled breach
10. **Reset Credentials**: Rotate all potentially compromised keys
11. **Verify Containment**: Confirm no ongoing unauthorized access
12. **Document Fixes**: Update security controls documentation

### Post-Incident (24-72 hours)
13. **Regulatory Reporting**: File breach notification (if required by HIPAA)
14. **User Notification**: Notify affected individuals (if required)
15. **Post-Mortem**: Conduct blameless retrospective
16. **Preventive Measures**: Implement additional controls
17. **Training**: Update security training materials
```

### Automated Alerting

```yaml
# Security Alert Policy
alert_policy:
  name: "PHI Data Access Anomaly"
  conditions:
    - display_name: "Unusual PHI Table Access"
      condition_threshold:
        filter: |
          resource.type="bigquery_resource"
          protoPayload.resourceName=~".*patient.*|.*claims.*"
          protoPayload.status.code=0
        aggregations:
          - alignment_period: "300s"
            per_series_aligner: "ALIGN_RATE"
        comparison: "COMPARISON_GT"
        threshold_value: 10  # More than 10 queries per 5 minutes
        duration: "300s"
  
  notification_channels:
    - projects/prod-healthcare-migration/notificationChannels/security-team
    - projects/prod-healthcare-migration/notificationChannels/pagerduty
  
  alert_strategy:
    auto_close: "1800s"
    notification_rate_limit:
      period: "300s"
```

---

## Security Testing

### Penetration Testing Schedule

```yaml
quarterly_tests:
  - name: "External Penetration Test"
    scope:
      - Public endpoints
      - VPN connections
      - Application security
    provider: "Third-party security firm"
    duration: "2 weeks"
  
  - name: "Internal Security Assessment"
    scope:
      - IAM configuration
      - Network security
      - Data encryption validation
    provider: "Internal security team"
    duration: "1 week"

annual_tests:
  - name: "HIPAA Security Assessment"
    scope:
      - All HIPAA Security Rule requirements
      - PHI handling procedures
      - Incident response
    provider: "HIPAA compliance auditor"
    duration: "4 weeks"
  
  - name: "Red Team Exercise"
    scope:
      - Full attack simulation
      - Social engineering
      - Physical security
    provider: "Third-party red team"
    duration: "2 weeks"
```

### Vulnerability Management

```bash
# Automated vulnerability scanning
gcloud scc findings list \
  --organization=ORGANIZATION_ID \
  --source=SECURITY_COMMAND_CENTER_SOURCE \
  --filter="state=ACTIVE AND severity IN (CRITICAL, HIGH)" \
  --format="table(
    finding.category,
    finding.name,
    finding.severity,
    finding.createTime
  )"

# Container vulnerability scanning
gcloud container images scan IMAGE_URL \
  --remote

gcloud container images describe IMAGE_URL \
  --show-package-vulnerability
```

### Security Metrics Dashboard

| Metric | Target | Current | Trend |
|--------|--------|---------|-------|
| **Mean Time to Detect (MTTD)** | < 5 minutes | 3 minutes | ↓ |
| **Mean Time to Respond (MTTR)** | < 30 minutes | 22 minutes | ↓ |
| **Failed Login Attempts** | < 10/day | 4/day | → |
| **Unauthorized Access Attempts** | 0 | 0 | → |
| **Unpatched Vulnerabilities (Critical)** | 0 | 0 | → |
| **Encryption Coverage** | 100% | 100% | → |
| **Audit Log Completeness** | 100% | 100% | → |

---

**Document Version**: 1.5  
**Last Updated**: February 2026  
**Next Review**: May 2026  
**Classification**: Internal Use Only  
**Owner**: Security & Compliance Team
