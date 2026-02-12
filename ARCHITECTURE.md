# Architecture Documentation

## Table of Contents
1. [System Architecture Overview](#system-architecture-overview)
2. [Network Architecture](#network-architecture)
3. [Data Flow Architecture](#data-flow-architecture)
4. [Security Architecture](#security-architecture)
5. [High Availability & Disaster Recovery](#high-availability--disaster-recovery)
6. [Scalability Considerations](#scalability-considerations)

---

## System Architecture Overview

### Design Principles

The migration architecture adheres to the following principles:

1. **Security-First Design**: All data paths encrypted, zero-trust model
2. **Scalability**: Horizontal scaling capabilities for growing data volumes
3. **Compliance by Design**: HIPAA/PHI controls embedded in architecture
4. **Cost Optimization**: Pay-per-use model with automatic resource scaling
5. **Observability**: Comprehensive logging, monitoring, and alerting
6. **Data Quality**: Built-in validation at every transformation stage

### Architecture Layers

```
┌─────────────────────────────────────────────────────────────────┐
│                        PRESENTATION LAYER                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │   Looker     │  │   Tableau    │  │  Custom Apps │         │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘         │
└─────────┼──────────────────┼──────────────────┼─────────────────┘
          │                  │                  │
          └──────────────────┼──────────────────┘
                             │
┌─────────────────────────────────────────────────────────────────┐
│                      DATA ACCESS LAYER                           │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  BigQuery Authorized Views                               │  │
│  │  - Row-level security applied                            │  │
│  │  - Column masking based on user roles                    │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                             │
┌─────────────────────────────────────────────────────────────────┐
│                      DATA SERVING LAYER                          │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  BigQuery Data Warehouse                                 │  │
│  │  ├─ prod_healthcare_data (Production)                    │  │
│  │  ├─ dev_healthcare_data (Development)                    │  │
│  │  └─ archive_healthcare_data (Historical)                 │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                             │
┌─────────────────────────────────────────────────────────────────┐
│                    DATA PROCESSING LAYER                         │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Cloud Dataflow Pipelines                                │  │
│  │  ├─ Extraction Pipeline (Hadoop → GCS)                  │  │
│  │  ├─ Transformation Pipeline (PII Masking)               │  │
│  │  ├─ Loading Pipeline (GCS → BigQuery)                   │  │
│  │  └─ Validation Pipeline (Quality Checks)                │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Cloud DLP (Data Loss Prevention)                        │  │
│  │  - PII/PHI Detection                                     │  │
│  │  - Field-level encryption                                │  │
│  │  - Tokenization services                                 │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                             │
┌─────────────────────────────────────────────────────────────────┐
│                       STAGING LAYER                              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Cloud Storage Buckets                                   │  │
│  │  ├─ raw_data_bucket (Hadoop extracts)                   │  │
│  │  ├─ processed_data_bucket (Transformed)                 │  │
│  │  ├─ archive_bucket (Long-term storage)                  │  │
│  │  └─ temp_dataflow_bucket (Dataflow temp)                │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                             │
┌─────────────────────────────────────────────────────────────────┐
│                        SOURCE LAYER                              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  On-Premises Hadoop Cluster                              │  │
│  │  - HDFS distributed file system                          │  │
│  │  - Hive metastore                                        │  │
│  │  - Parquet/ORC formatted data                            │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Network Architecture

### Connectivity Model

```
┌─────────────────────────────────────────────────────────────────┐
│                    ON-PREMISES DATACENTER                        │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Hadoop Cluster (10.0.0.0/16)                            │  │
│  │  ├─ Master Nodes: 10.0.1.0/24                           │  │
│  │  ├─ Worker Nodes: 10.0.2.0/23                           │  │
│  │  └─ Edge Nodes: 10.0.4.0/24                             │  │
│  └────────────────┬─────────────────────────────────────────┘  │
│                   │                                              │
│  ┌────────────────▼─────────────────────────────────────────┐  │
│  │  Corporate Firewall                                       │  │
│  │  - Outbound: Port 443 (HTTPS) to GCP                    │  │
│  │  - IP Allowlist: GCP Cloud Router IPs                   │  │
│  └────────────────┬─────────────────────────────────────────┘  │
└────────────────────┼─────────────────────────────────────────────┘
                     │
                     │ Cloud VPN (HA VPN - 99.99% SLA)
                     │ or
                     │ Cloud Interconnect (Dedicated 10Gbps)
                     │
┌────────────────────▼─────────────────────────────────────────────┐
│                    GOOGLE CLOUD PLATFORM                          │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  VPC Network (healthcare-migration-vpc)                  │  │
│  │  - Region: us-central1                                   │  │
│  │  - CIDR: 172.16.0.0/16                                   │  │
│  │                                                           │  │
│  │  Subnets:                                                 │  │
│  │  ├─ dataflow-subnet: 172.16.1.0/24                      │  │
│  │  ├─ bigquery-subnet: 172.16.2.0/24                      │  │
│  │  └─ management-subnet: 172.16.10.0/24                   │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  VPC Service Controls Perimeter                          │  │
│  │  - Protected Services: BigQuery, Cloud Storage, DLP      │  │
│  │  - Access Level Policies                                 │  │
│  │  - Ingress/Egress Rules                                  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Cloud NAT                                                │  │
│  │  - Provides internet access for private resources        │  │
│  │  - Static external IPs for logging                       │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Private Google Access                                    │  │
│  │  - Access GCP services without internet                  │  │
│  │  - Routes: 199.36.153.8/30 → default-internet-gateway   │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Network Security Controls

| Control | Implementation | Purpose |
|---------|----------------|---------|
| **VPC Service Controls** | Perimeter around BigQuery, GCS, DLP | Prevent data exfiltration |
| **Private Google Access** | Enabled on all subnets | Secure API communication |
| **Cloud NAT** | Regional NAT gateway | Controlled outbound access |
| **Firewall Rules** | Allow only required ports/protocols | Network segmentation |
| **Cloud Armor** | DDoS protection for public endpoints | Attack mitigation |
| **VPN/Interconnect** | Encrypted tunnel to on-prem | Secure data transfer |

---

## Data Flow Architecture

### End-to-End Data Journey

```
┌─────────────────────────────────────────────────────────────────┐
│ PHASE 1: EXTRACTION (Hadoop → Cloud Storage)                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  1. Distcp Job (Hadoop)                                          │
│     ├─ Read from HDFS                                            │
│     ├─ Compress (gzip)                                           │
│     └─ Write to GCS raw bucket                                   │
│                                                                   │
│  2. Metadata Extraction                                          │
│     ├─ Hive metastore → BigQuery                                 │
│     ├─ Table schemas                                             │
│     ├─ Partition info                                            │
│     └─ Statistics                                                │
│                                                                   │
│  Validation: File checksums, row counts                          │
└─────────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ PHASE 2: TRANSFORMATION (Cloud Dataflow)                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  3. Data Quality Pipeline                                        │
│     ├─ Schema validation                                         │
│     ├─ Null checks                                               │
│     ├─ Data type validation                                      │
│     ├─ Business rule validation                                  │
│     └─ Anomaly detection                                         │
│                                                                   │
│  4. PII/PHI Detection (Cloud DLP)                                │
│     ├─ Scan for SSN patterns                                     │
│     ├─ Detect email addresses                                    │
│     ├─ Find phone numbers                                        │
│     ├─ Identify dates of birth                                   │
│     └─ Detect medical record numbers                             │
│                                                                   │
│  5. Data Masking                                                 │
│     ├─ Tokenization (SSN, MRN)                                   │
│     ├─ Hashing (Email, Phone)                                    │
│     ├─ Pseudonymization (Names)                                  │
│     ├─ Date shifting (DOB)                                       │
│     └─ Encryption (Addresses)                                    │
│                                                                   │
│  6. Data Enrichment                                              │
│     ├─ Add audit columns (created_at, updated_at)                │
│     ├─ Add source metadata                                       │
│     ├─ Calculate derived fields                                  │
│     └─ Apply business logic                                      │
│                                                                   │
│  Output: Parquet files in processed bucket                       │
└─────────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ PHASE 3: LOADING (BigQuery)                                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  7. BigQuery Load Jobs                                           │
│     ├─ Schema definition applied                                 │
│     ├─ Partition by date                                         │
│     ├─ Cluster by key columns                                    │
│     └─ Enable table encryption (CMEK)                            │
│                                                                   │
│  8. Post-Load Processing                                         │
│     ├─ Create authorized views                                   │
│     ├─ Apply row-level security                                  │
│     ├─ Create materialized views                                 │
│     └─ Update table statistics                                   │
│                                                                   │
│  Validation: Row count reconciliation, sample data verification  │
└─────────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ PHASE 4: GOVERNANCE (Collibra Integration)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  9. Metadata Synchronization                                     │
│     ├─ BigQuery schema → Collibra                                │
│     ├─ Table descriptions                                        │
│     ├─ Column-level metadata                                     │
│     └─ Data lineage relationships                                │
│                                                                   │
│  10. Policy Application                                          │
│      ├─ Classify sensitive columns                               │
│      ├─ Apply data tags                                          │
│      ├─ Assign data stewards                                     │
│      └─ Enable access workflows                                  │
│                                                                   │
│  11. Quality Monitoring                                          │
│      ├─ Calculate quality scores                                 │
│      ├─ Track data freshness                                     │
│      ├─ Monitor completeness                                     │
│      └─ Alert on anomalies                                       │
└─────────────────────────────────────────────────────────────────┘
```

### Pipeline Orchestration

The migration uses Apache Airflow (Cloud Composer) for orchestration:

```python
# Simplified DAG structure
migration_dag = DAG(
    dag_id='hadoop_to_bigquery_migration',
    schedule_interval=None,  # Manual trigger
    default_args={
        'owner': 'data-engineering',
        'retries': 3,
        'retry_delay': timedelta(minutes=5)
    }
)

# Task dependencies
extract_hadoop >> validate_extraction >> transform_data >> mask_pii >> \
load_bigquery >> validate_load >> sync_collibra >> notify_completion
```

---

## Security Architecture

### Defense in Depth Strategy

```
┌─────────────────────────────────────────────────────────────────┐
│ Layer 1: Network Security                                       │
│ ├─ VPC Service Controls                                         │
│ ├─ Private Google Access                                        │
│ ├─ Cloud Armor (DDoS protection)                                │
│ └─ Firewall rules (least privilege)                             │
└─────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────┐
│ Layer 2: Identity & Access Management                           │
│ ├─ Workload Identity Federation                                 │
│ ├─ Service accounts per pipeline                                │
│ ├─ Custom IAM roles (least privilege)                           │
│ ├─ Multi-factor authentication                                  │
│ └─ Just-in-time access                                           │
└─────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────┐
│ Layer 3: Data Protection                                        │
│ ├─ Encryption at rest (CMEK)                                    │
│ ├─ Encryption in transit (TLS 1.3)                              │
│ ├─ Field-level encryption                                       │
│ ├─ PII/PHI masking                                              │
│ └─ Tokenization                                                  │
└─────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────┐
│ Layer 4: Application Security                                   │
│ ├─ Input validation                                             │
│ ├─ SQL injection prevention                                     │
│ ├─ Dependency scanning                                          │
│ └─ Secure coding practices                                      │
└─────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────┐
│ Layer 5: Monitoring & Audit                                     │
│ ├─ Cloud Audit Logs (Admin, Data Access, System)                │
│ ├─ Cloud Logging (application logs)                             │
│ ├─ Security Command Center                                      │
│ ├─ Anomaly detection                                            │
│ └─ Incident response playbooks                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Encryption Architecture

#### Data at Rest

```
BigQuery Table
    ↓
CMEK (Customer-Managed Encryption Key)
    ↓
Cloud KMS Key Ring
    ↓
└─ Key: bigquery-healthcare-key
   ├─ Rotation: Automatic (90 days)
   ├─ Algorithm: AES-256-GCM
   └─ Location: us-central1

Cloud Storage Bucket
    ↓
CMEK (Customer-Managed Encryption Key)
    ↓
Cloud KMS Key Ring
    ↓
└─ Key: gcs-healthcare-key
   ├─ Rotation: Automatic (90 days)
   ├─ Algorithm: AES-256-GCM
   └─ Location: us-central1
```

#### Data in Transit

- All connections use TLS 1.3
- Certificate pinning for API connections
- Perfect Forward Secrecy (PFS) enabled
- Strong cipher suites only (AES-GCM)

---

## High Availability & Disaster Recovery

### Availability Design

| Component | HA Configuration | SLA Target |
|-----------|------------------|------------|
| **BigQuery** | Multi-regional (US) | 99.99% |
| **Cloud Storage** | Dual-region | 99.99% |
| **Cloud Dataflow** | Regional with auto-restart | 99.9% |
| **Cloud DLP** | Global service | 99.9% |
| **VPN/Interconnect** | HA VPN (dual tunnels) | 99.99% |

### Disaster Recovery Strategy

```
┌─────────────────────────────────────────────────────────────────┐
│ RPO (Recovery Point Objective): 1 hour                          │
│ RTO (Recovery Time Objective): 4 hours                          │
└─────────────────────────────────────────────────────────────────┘

Backup Strategy:
├─ BigQuery
│  ├─ Automated snapshots (daily)
│  ├─ Cross-region replication (US → EU)
│  └─ Point-in-time recovery (7 days)
│
├─ Cloud Storage
│  ├─ Versioning enabled
│  ├─ Lifecycle policies (90-day retention)
│  └─ Cross-region bucket replication
│
└─ Infrastructure as Code
   ├─ Terraform state in GCS (versioned)
   ├─ Git repository (multiple remotes)
   └─ Automated drift detection

Recovery Procedures:
1. Detect failure (monitoring alerts)
2. Activate DR team (on-call rotation)
3. Assess impact and determine recovery path
4. Execute runbook procedures
5. Verify data integrity
6. Failover application traffic
7. Post-incident review
```

### Backup Schedule

| Data Type | Frequency | Retention | Location |
|-----------|-----------|-----------|----------|
| **Production Tables** | Daily | 30 days | us-central1, us-east1 |
| **Archive Data** | Weekly | 7 years | Coldline Storage |
| **Configuration** | On change | Indefinite | Version control |
| **Logs** | Real-time | 90 days | Cloud Logging |
| **Audit Trail** | Real-time | 7 years | BigQuery archive |

---

## Scalability Considerations

### Horizontal Scaling

```
Current Scale:
├─ Data Volume: 12.5 TB
├─ Tables: 85 tables
├─ Daily Ingestion: 50 GB
├─ Concurrent Users: 200
└─ Query Volume: 10,000/day

Scale Target (3 years):
├─ Data Volume: 50 TB (4x growth)
├─ Tables: 200 tables
├─ Daily Ingestion: 200 GB (4x growth)
├─ Concurrent Users: 500 (2.5x growth)
└─ Query Volume: 50,000/day (5x growth)

Scaling Strategy:
├─ BigQuery: Automatic (no action needed)
├─ Cloud Storage: Automatic (no action needed)
├─ Dataflow: Increase worker nodes (configurable)
└─ Cost: Linear scaling with volume
```

### Performance Optimization

#### BigQuery Optimization

1. **Partitioning**: All large tables partitioned by date
2. **Clustering**: Key columns clustered for common query patterns
3. **Materialized Views**: Pre-aggregated data for dashboards
4. **BI Engine**: 100 GB allocation for sub-second queries
5. **Result Caching**: Enabled for repeated queries

#### Query Performance

```sql
-- Example optimized query structure
SELECT 
    patient_id,
    COUNT(DISTINCT claim_id) as total_claims,
    SUM(claim_amount) as total_amount
FROM `project.dataset.claims`
WHERE 
    _PARTITIONDATE BETWEEN '2024-01-01' AND '2024-12-31'
    AND claim_status = 'APPROVED'
GROUP BY patient_id
-- Partition pruning reduces scan from 12.5TB to 500GB
-- Clustering on patient_id improves GROUP BY performance
```

### Resource Allocation

| Pipeline | Max Workers | Machine Type | Network | Storage |
|----------|-------------|--------------|---------|---------|
| **Extraction** | 50 | n1-standard-4 | 10 Gbps | 100 GB temp |
| **Transformation** | 100 | n1-highmem-8 | 10 Gbps | 500 GB temp |
| **Loading** | 20 | n1-standard-2 | 10 Gbps | 50 GB temp |
| **Validation** | 30 | n1-standard-4 | 10 Gbps | 100 GB temp |

---

## Monitoring Architecture

### Observability Stack

```
┌─────────────────────────────────────────────────────────────────┐
│ Cloud Monitoring                                                 │
│ ├─ Metrics: CPU, Memory, Disk, Network                          │
│ ├─ Custom Metrics: Pipeline throughput, data quality scores     │
│ ├─ Uptime Checks: API endpoints, services                       │
│ └─ Dashboards: 5 pre-built, 3 custom                            │
└─────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────┐
│ Cloud Logging                                                    │
│ ├─ Application Logs: Pipeline execution logs                    │
│ ├─ Audit Logs: Data access, configuration changes               │
│ ├─ System Logs: GCP service logs                                │
│ └─ Log-based Metrics: Error rates, latency percentiles          │
└─────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────┐
│ Cloud Trace                                                      │
│ ├─ Request tracing: End-to-end pipeline latency                 │
│ ├─ Performance profiling: Bottleneck identification             │
│ └─ Dependency mapping: Service interactions                     │
└─────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────┐
│ Alerting Policies                                                │
│ ├─ Critical: Data pipeline failures, security violations        │
│ ├─ Warning: High error rates, approaching quotas                │
│ ├─ Info: Successful migrations, scheduled jobs                  │
│ └─ Channels: Email, PagerDuty, Slack                            │
└─────────────────────────────────────────────────────────────────┘
```

### Key Performance Indicators (KPIs)

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| **Pipeline Success Rate** | > 99.5% | < 98% |
| **Data Quality Score** | > 99% | < 97% |
| **Query P95 Latency** | < 15s | > 30s |
| **Data Freshness** | < 1 hour | > 2 hours |
| **Cost per TB** | < $25 | > $35 |
| **Security Incidents** | 0 | > 0 |

---

## Cost Architecture

### Cost Breakdown (Monthly)

```
Total Monthly Cost: ~$18,500

BigQuery:
├─ Storage: $5,000 (12.5 TB active, 5 TB long-term)
├─ Query Processing: $8,000 (40 TB scanned/month)
└─ Streaming Inserts: $500 (50 GB/day)

Cloud Storage:
├─ Regional Storage: $2,000 (50 TB total)
├─ Data Transfer: $800 (outbound to BigQuery)
└─ Operations: $200 (API calls)

Cloud Dataflow:
├─ Compute: $1,500 (100 vCPUs average)
└─ Licensing: Included

Other Services:
├─ Cloud DLP: $300 (inspection requests)
├─ Cloud KMS: $50 (key operations)
├─ Cloud NAT: $100 (egress traffic)
└─ Monitoring/Logging: $50

Cost Optimization Strategies:
✓ Use long-term storage pricing for historical data
✓ Partition pruning to reduce query costs
✓ Scheduled queries during off-peak hours
✓ Committed use discounts (30% savings)
✓ Flat-rate BigQuery pricing for predictable costs
```

---

## Future Architecture Enhancements

### Planned Improvements

1. **Real-Time Streaming**: Implement Cloud Pub/Sub → Dataflow → BigQuery pipeline
2. **Machine Learning**: Integrate Vertex AI for predictive analytics
3. **Data Mesh**: Distributed data ownership with domain-specific datasets
4. **Multi-Cloud**: Extend to Azure for disaster recovery
5. **Advanced Security**: Implement Confidential Computing for data in use

### Technology Roadmap

```
Q1 2026: Real-time ingestion pipeline
Q2 2026: ML-powered anomaly detection
Q3 2026: Data mesh implementation
Q4 2026: Multi-cloud DR setup
Q1 2027: Zero-trust architecture completion
```

---

**Document Version**: 2.0  
**Last Updated**: February 2026  
**Next Review**: May 2026  
**Owner**: Cloud Architecture Team
