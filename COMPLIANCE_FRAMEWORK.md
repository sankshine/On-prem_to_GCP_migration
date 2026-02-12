## HIPAA Overview

### Regulatory Scope

The Health Insurance Portability and Accountability Act (HIPAA) establishes national standards to protect individuals' medical records and other Protected Health Information (PHI).

### Protected Health Information (PHI)

PHI includes any of the following 18 identifiers when associated with health information:

1. Names
2. Geographic subdivisions smaller than a state
3. Dates (except year) directly related to an individual
4. Telephone numbers
5. Fax numbers
6. Email addresses
7. Social Security numbers
8. Medical record numbers
9. Health plan beneficiary numbers
10. Account numbers
11. Certificate/license numbers
12. Vehicle identifiers and serial numbers
13. Device identifiers and serial numbers
14. Web URLs
15. IP addresses
16. Biometric identifiers
17. Full-face photographs
18. Any other unique identifying number or code


## Technical Safeguards

### Encryption Implementation

#### Data at Rest
**Cloud KMS (Customer-Managed Encryption Keys):**
- Created dedicated KMS key rings and crypto keys specifically for BigQuery datasets
- Set up key rotation policies (90-day rotation period) as defined in `kms_key_rotation_period`
- Applied IAM bindings granting BigQuery service accounts permission to use these keys (`roles/cloudkms.cryptoKeyEncrypterDecrypter`)
- Enabled `prevent_destroy` lifecycle rule to protect KMS keys from accidental deletion

**Data in Transit (Automatic GCP Encryption):**
- All data moving between services (Dataflow → BigQuery, GCS → Dataflow) automatically encrypted via TLS 1.2+ by GCP's default infrastructure
- VPC network configured with `private_ip_google_access = true`, keeping traffic on Google's internal encrypted backbone


## Administrative Safeguards

### Security Policies and Procedures

#### Access Request Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│ PHI Access Request Process                                      │
└─────────────────────────────────────────────────────────────────┘

1. Employee submits access request
   ├─ Business justification required
   ├─ Manager approval required
   └─ Security team review
   
2. Role determination
   ├─ Minimum necessary principle applied
   ├─ Time-limited access (default: 90 days)
   └─ Specific dataset/table scope
   
3. Access provisioning
   ├─ IAM role assignment
   └─ Security training completion check
   
4. Ongoing monitoring
   ├─ Quarterly access reviews
   └─ Automatic revocation on termination
   
5. Audit trail
   ├─ All approvals logged
   └─ Access usage tracked
```



