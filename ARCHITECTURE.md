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


### Performance Optimization

#### BigQuery Optimization

1. **Partitioning**: All large tables partitioned by date
2. **Clustering**: Key columns clustered for common query patterns
3. **Materialized Views**: Pre-aggregated data for dashboards
4. **Result Caching**: Enabled for repeated queries


## Cost Architecture

### Cost Breakdown (Monthly)

```
Total Monthly Cost: ~$XX

BigQuery:
├─ Storage: $XX
├─ Query Processing: $XX
└─ Streaming Inserts: $XX

Cloud Storage:
├─ Regional Storage: $XX
├─ Data Transfer: $XX
└─ Operations: $XX

Cloud Dataflow:
├─ Compute: $XX
└─ Licensing: Included

Other Services:
├─ Cloud DLP: $XX
└─ Monitoring/Logging: $XX

Cost Optimization Strategies:
✓ Partition pruning to reduce query costs
✓ Scheduled queries during off-peak hours
✓ Committed use discounts (30% savings)
✓ Flat-rate BigQuery pricing for predictable costs
```

---

