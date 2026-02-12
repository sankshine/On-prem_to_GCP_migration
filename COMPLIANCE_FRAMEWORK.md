# HIPAA/PHI Compliance Framework

## Table of Contents
1. [HIPAA Overview](#hipaa-overview)
2. [Regulatory Requirements](#regulatory-requirements)
3. [Technical Safeguards](#technical-safeguards)
4. [Administrative Safeguards](#administrative-safeguards)
5. [Physical Safeguards](#physical-safeguards)
6. [Compliance Validation](#compliance-validation)
7. [Breach Notification](#breach-notification)

---

## HIPAA Overview

### Regulatory Scope

The Health Insurance Portability and Accountability Act (HIPAA) establishes national standards to protect individuals' medical records and other Protected Health Information (PHI).

**Applicable Rules:**
- **Privacy Rule** (45 CFR Part 160 and Subparts A and E of Part 164)
- **Security Rule** (45 CFR Part 160 and Subparts A and C of Part 164)
- **Breach Notification Rule** (45 CFR Part 160 and Subparts A and D of Part 164)
- **Enforcement Rule** (45 CFR Part 160, Subparts C, D, and E)

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

---

## Regulatory Requirements

### HIPAA Security Rule Requirements

The Security Rule requires covered entities and business associates to implement safeguards across three categories:

#### 1. Administrative Safeguards (§164.308)

| Standard | Implementation Specification | Our Implementation | Status |
|----------|----------------------------|-------------------|--------|
| **Security Management Process** | Risk Analysis | Annual risk assessments, quarterly reviews | ✅ |
| | Risk Management | Documented risk mitigation plans | ✅ |
| | Sanction Policy | Employee disciplinary procedures | ✅ |
| | Information System Activity Review | Cloud Audit Logs, SIEM monitoring | ✅ |
| **Assigned Security Responsibility** | Security Officer | Designated CISO and Security Team | ✅ |
| **Workforce Security** | Authorization/Supervision | IAM roles, least privilege | ✅ |
| | Workforce Clearance | Background checks, security training | ✅ |
| | Termination Procedures | Automated access revocation | ✅ |
| **Information Access Management** | Access Authorization | Role-based access control (RBAC) | ✅ |
| | Access Establishment | Documented provisioning process | ✅ |
| | Access Modification | Change management workflow | ✅ |
| **Security Awareness Training** | Security Reminders | Quarterly security bulletins | ✅ |
| | Protection from Malicious Software | Endpoint protection, container scanning | ✅ |
| | Log-in Monitoring | Failed login tracking and alerting | ✅ |
| | Password Management | MFA required, password complexity | ✅ |
| **Security Incident Procedures** | Response and Reporting | Incident response playbook | ✅ |
| **Contingency Plan** | Data Backup Plan | Automated daily backups | ✅ |
| | Disaster Recovery Plan | Cross-region replication, tested quarterly | ✅ |
| | Emergency Mode Operation | Failover procedures documented | ✅ |
| | Testing and Revision | Annual DR tests | ✅ |
| **Evaluation** | Periodic Evaluation | Annual compliance audits | ✅ |
| **Business Associate Contracts** | Written Contract | GCP BAA executed | ✅ |

#### 2. Physical Safeguards (§164.310)

| Standard | Implementation Specification | Our Implementation | Status |
|----------|----------------------------|-------------------|--------|
| **Facility Access Controls** | Contingency Operations | Cloud provider physical security | ✅ |
| | Facility Security Plan | GCP data center certifications | ✅ |
| | Access Control and Validation | Biometric access (GCP facilities) | ✅ |
| | Maintenance Records | GCP audit trails | ✅ |
| **Workstation Use** | Workstation Use Policy | Encrypted laptops, screen locks | ✅ |
| **Workstation Security** | Physical Safeguards | Locked offices, cable locks | ✅ |
| **Device and Media Controls** | Disposal | Secure deletion procedures | ✅ |
| | Media Re-use | Data sanitization before reuse | ✅ |
| | Accountability | Asset tracking system | ✅ |
| | Data Backup and Storage | Encrypted backups, offsite storage | ✅ |

#### 3. Technical Safeguards (§164.312)

| Standard | Implementation Specification | Our Implementation | Status |
|----------|----------------------------|-------------------|--------|
| **Access Control** | Unique User Identification | Individual IAM accounts, no shared credentials | ✅ |
| | Emergency Access Procedure | Break-glass accounts with audit logging | ✅ |
| | Automatic Logoff | Session timeout (30 minutes) | ✅ |
| | Encryption and Decryption | CMEK, TLS 1.3, field-level encryption | ✅ |
| **Audit Controls** | Audit Controls | Cloud Audit Logs for all PHI access | ✅ |
| **Integrity** | Mechanism to Authenticate ePHI | Checksums, digital signatures | ✅ |
| **Person or Entity Authentication** | Authentication | MFA required for all users | ✅ |
| **Transmission Security** | Integrity Controls | TLS 1.3 for all data in transit | ✅ |
| | Encryption | End-to-end encryption | ✅ |

---

## Technical Safeguards

### Encryption Implementation

#### Data at Rest

```yaml
Encryption Configuration:
  BigQuery:
    Method: Customer-Managed Encryption Keys (CMEK)
    Algorithm: AES-256-GCM
    Key Location: Cloud KMS (us-central1)
    Key Rotation: Automatic (90 days)
    Key Management: Hardware Security Module (HSM)
    
  Cloud Storage:
    Method: CMEK
    Algorithm: AES-256-GCM
    Key Location: Cloud KMS (us-central1)
    Key Rotation: Automatic (90 days)
    Additional: Object versioning enabled
    
  Field-Level Encryption:
    Sensitive Fields: SSN, MRN, Credit Card
    Method: Application-layer encryption
    Algorithm: AES-256-GCM
    Key Storage: Cloud KMS
```

#### Data in Transit

```yaml
Transmission Security:
  Protocol: TLS 1.3
  Cipher Suites:
    - TLS_AES_256_GCM_SHA384
    - TLS_AES_128_GCM_SHA256
    - TLS_CHACHA20_POLY1305_SHA256
  
  Certificate Authority: Google Trust Services
  Certificate Validity: 90 days
  Certificate Renewal: Automatic
  
  VPN Configuration:
    Type: HA VPN (IPSec)
    IKE Version: IKEv2
    Encryption: AES-256-GCM
    Integrity: SHA2-384
    DH Group: 20 (384-bit ECC)
    Perfect Forward Secrecy: Yes
```

### Access Control Matrix

#### Role-Based Access Control (RBAC)

```
┌─────────────────────────────────────────────────────────────────┐
│ Access Control Hierarchy                                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Data Access Level:                                              │
│  ├─ Level 1: De-identified Data (Analyst Role)                 │
│  │   ├─ View aggregated reports                                │
│  │   ├─ Run predefined queries                                 │
│  │   └─ No direct PHI access                                   │
│  │                                                               │
│  ├─ Level 2: Limited PHI (Data Scientist Role)                 │
│  │   ├─ Access to specific authorized views                    │
│  │   ├─ Row-level security applied                             │
│  │   └─ Column masking enforced                                │
│  │                                                               │
│  ├─ Level 3: Full PHI (Data Engineer Role)                     │
│  │   ├─ Read/write access to all tables                        │
│  │   ├─ Pipeline execution permissions                         │
│  │   └─ DLP API access                                         │
│  │                                                               │
│  └─ Level 4: Administrative (Security Admin)                    │
│      ├─ IAM policy management                                   │
│      ├─ Audit log access                                        │
│      └─ Security configuration                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### Multi-Factor Authentication (MFA)

```yaml
MFA Configuration:
  Enforcement: Required for all users
  Methods:
    - Google Authenticator (TOTP)
    - Security keys (U2F/WebAuthn)
    - SMS backup (restricted)
  
  Service Accounts:
    - Workload Identity Federation
    - Short-lived tokens (1 hour)
    - No long-term credentials
  
  Break-Glass Accounts:
    - MFA required
    - Audit logged
    - Time-limited access
    - Quarterly rotation
```

### Audit Logging

#### Comprehensive Logging Strategy

```sql
-- Example: Query to audit PHI access
SELECT
  timestamp,
  protoPayload.authenticationInfo.principalEmail AS user_email,
  protoPayload.resourceName AS resource_accessed,
  protoPayload.methodName AS action,
  protoPayload.requestMetadata.callerIp AS source_ip,
  protoPayload.metadata.tableDataRead.fields AS fields_accessed,
  protoPayload.status.code AS status_code
FROM
  `project.audit_logs.cloudaudit_googleapis_com_data_access`
WHERE
  protoPayload.resourceName LIKE '%patient%'
  OR protoPayload.resourceName LIKE '%claims%'
  OR protoPayload.resourceName LIKE '%phi%'
ORDER BY
  timestamp DESC;
```

#### Log Retention Policy

| Log Type | Retention Period | Storage Location | Justification |
|----------|-----------------|------------------|---------------|
| **Access Logs** | 7 years | BigQuery archive | HIPAA requirement (§164.316(b)(2)(i)) |
| **Admin Logs** | 7 years | BigQuery archive | Compliance and forensics |
| **System Logs** | 90 days | Cloud Logging | Operational troubleshooting |
| **Security Logs** | 7 years | BigQuery archive + SIEM | Incident investigation |
| **Audit Trails** | 7 years | Immutable storage | Legal hold capability |

---

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
   ├─ MFA verification
   └─ Security training completion check
   
4. Ongoing monitoring
   ├─ Quarterly access reviews
   ├─ Anomaly detection
   └─ Automatic revocation on termination
   
5. Audit trail
   ├─ All approvals logged
   ├─ Access usage tracked
   └─ Periodic certification required
```

### Workforce Training

```yaml
Security Awareness Training Program:
  
  Initial Training (New Hires):
    Duration: 4 hours
    Topics:
      - HIPAA fundamentals
      - PHI handling procedures
      - Data classification
      - Incident reporting
      - Security best practices
    Completion: Required before system access
    
  Annual Refresher:
    Duration: 2 hours
    Topics:
      - Updated policies
      - Recent incidents and lessons learned
      - Emerging threats
      - Compliance updates
    Completion: Required annually
    
  Role-Specific Training:
    Data Engineers:
      - Secure coding practices
      - DLP configuration
      - Encryption implementation
    
    Analysts:
      - Query best practices
      - Data minimization
      - De-identification techniques
    
    Administrators:
      - IAM configuration
      - Audit log analysis
      - Incident response
  
  Phishing Simulations:
    Frequency: Quarterly
    Failure Threshold: Mandatory retraining
```

### Risk Management

#### Risk Assessment Methodology

```
┌─────────────────────────────────────────────────────────────────┐
│ HIPAA Risk Assessment Matrix                                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Risk = Likelihood × Impact                                      │
│                                                                   │
│  Likelihood Scale:                                               │
│  1 = Rare (< 1% chance)                                         │
│  2 = Unlikely (1-10% chance)                                    │
│  3 = Possible (10-50% chance)                                   │
│  4 = Likely (50-90% chance)                                     │
│  5 = Almost Certain (> 90% chance)                              │
│                                                                   │
│  Impact Scale:                                                   │
│  1 = Minimal (< 10 records)                                     │
│  2 = Minor (10-100 records)                                     │
│  3 = Moderate (100-1,000 records)                               │
│  4 = Major (1,000-10,000 records)                               │
│  5 = Catastrophic (> 10,000 records)                            │
│                                                                   │
│  Risk Score = Likelihood × Impact (1-25)                        │
│  ├─ 1-5: Low Risk (Accept)                                      │
│  ├─ 6-10: Medium Risk (Mitigate)                                │
│  ├─ 11-15: High Risk (Urgent mitigation)                        │
│  └─ 16-25: Critical Risk (Immediate action)                     │
└─────────────────────────────────────────────────────────────────┘
```

#### Current Risk Register

| Risk ID | Description | Likelihood | Impact | Risk Score | Mitigation | Owner |
|---------|-------------|------------|--------|------------|------------|-------|
| **R001** | Unauthorized PHI access | 2 | 4 | 8 | IAM, MFA, audit logs | Security Team |
| **R002** | Data exfiltration | 1 | 5 | 5 | VPC Service Controls, DLP | Security Team |
| **R003** | Insider threat | 2 | 4 | 8 | User behavior analytics | CISO |
| **R004** | Encryption key loss | 1 | 5 | 5 | KMS, key backup | Platform Team |
| **R005** | Third-party breach | 2 | 3 | 6 | Vendor assessment, BAA | Legal/Security |
| **R006** | Misconfiguration | 3 | 3 | 9 | IaC, policy enforcement | DevOps |
| **R007** | DDoS attack | 2 | 2 | 4 | Cloud Armor, load balancing | Platform Team |

---

## Physical Safeguards

### GCP Data Center Security

Google Cloud Platform data centers provide physical security controls that satisfy HIPAA requirements:

#### Physical Access Controls

```yaml
GCP Data Center Security:
  
  Perimeter Security:
    - 24/7 security guard presence
    - Vehicle barriers
    - Security cameras (internal/external)
    - Motion detection systems
    
  Building Access:
    - Biometric authentication required
    - Two-factor authentication
    - Security escort for visitors
    - Access logs maintained
    
  Server Floor Access:
    - Additional biometric scan
    - Badge access with photo verification
    - Man-trap entry
    - Continuous video surveillance
    
  Equipment Security:
    - Locked server racks
    - Tamper-evident seals
    - Asset tracking with barcodes/RFID
    - Secure decommissioning process
```

### Data Destruction Procedures

```
┌─────────────────────────────────────────────────────────────────┐
│ Secure Data Destruction Process                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Cloud Storage Objects:                                          │
│  1. Soft delete (30-day recovery window)                        │
│  2. KMS key destruction after retention period                  │
│  3. Automatic cryptographic erasure                             │
│  4. Audit log entry generated                                   │
│                                                                   │
│  BigQuery Tables:                                                │
│  1. Table deletion with snapshot retention                      │
│  2. Snapshot expiration after 7 years                           │
│  3. Encrypted with separate KMS key                             │
│  4. Key destruction after retention                             │
│                                                                   │
│  Physical Media (GCP Responsibility):                            │
│  1. Multi-pass overwrite (DoD 5220.22-M)                        │
│  2. Degaussing for magnetic media                               │
│  3. Physical destruction (shredding)                            │
│  4. Certificate of Destruction issued                           │
└─────────────────────────────────────────────────────────────────┘
```

---

## Compliance Validation

### Compliance Checklist

```markdown
## HIPAA Security Rule Compliance Checklist

### Administrative Safeguards
- [x] Risk Analysis completed (last: 2025-12-15)
- [x] Risk Management Plan documented
- [x] Sanction Policy established
- [x] Information System Activity Review (automated)
- [x] Security Officer assigned (CISO)
- [x] Workforce Security procedures documented
- [x] Access Management policies established
- [x] Security Training program implemented
- [x] Incident Response procedures documented
- [x] Contingency Plan created and tested
- [x] Business Associate Agreement (BAA) executed with GCP

### Physical Safeguards
- [x] Facility Access Controls (GCP data centers)
- [x] Workstation Use Policy documented
- [x] Workstation Security procedures
- [x] Device and Media Controls established

### Technical Safeguards
- [x] Unique User Identification (IAM)
- [x] Emergency Access Procedure (break-glass)
- [x] Automatic Logoff (30-minute timeout)
- [x] Encryption at Rest (CMEK)
- [x] Encryption in Transit (TLS 1.3)
- [x] Audit Controls (Cloud Audit Logs)
- [x] Integrity Controls (checksums)
- [x] Multi-Factor Authentication (MFA)

### Documentation
- [x] Policies and Procedures documented
- [x] Security Configuration documented
- [x] Audit Logs maintained (7-year retention)
- [x] Training Records maintained
- [x] Risk Assessment Reports archived
- [x] Incident Response Logs maintained
```

### External Audit Reports

```yaml
Compliance Audits:
  
  HIPAA Compliance Assessment:
    Frequency: Annual
    Auditor: Third-party HIPAA auditor
    Last Assessment: 2025-11-20
    Next Assessment: 2026-11-20
    Findings: 0 critical, 2 minor (remediated)
    Status: Compliant
    
  Penetration Testing:
    Frequency: Quarterly
    Provider: External security firm
    Last Test: 2025-12-15
    Scope: External perimeter, VPN, application security
    Findings: 0 critical, 1 medium (remediated)
    
  Vulnerability Scanning:
    Frequency: Continuous
    Tool: Security Command Center
    Auto-remediation: Enabled for critical
    Current Status: 0 critical, 3 medium
```

### Compliance Metrics Dashboard

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| **Audit Log Completeness** | 100% | 100% | ✅ |
| **Encryption Coverage** | 100% | 100% | ✅ |
| **MFA Adoption** | 100% | 100% | ✅ |
| **Security Training Completion** | 100% | 98% | ⚠️ |
| **Access Review Completion** | 100% | 100% | ✅ |
| **Vulnerability Remediation** | < 30 days | 12 days avg | ✅ |
| **Incident Response Time** | < 30 min | 22 min avg | ✅ |
| **Unauthorized Access Attempts** | 0 | 0 | ✅ |
| **Data Breach Incidents** | 0 | 0 | ✅ |

---

## Breach Notification

### Breach Determination Process

```
┌─────────────────────────────────────────────────────────────────┐
│ HIPAA Breach Notification Decision Tree                         │
└─────────────────────────────────────────────────────────────────┘

Has there been an impermissible use or disclosure of PHI?
│
├─ No → No breach notification required
│
└─ Yes → Was the PHI secured (encrypted)?
    │
    ├─ Yes → Low probability of compromise
    │   └─ Document exception, no notification
    │
    └─ No → Apply 4-Factor Risk Assessment:
        │
        ├─ 1. Nature and extent of PHI
        ├─ 2. Unauthorized person who used/disclosed PHI
        ├─ 3. Was PHI actually acquired or viewed?
        └─ 4. Extent of risk mitigation
        
        Risk Assessment Conclusion:
        │
        ├─ Low Risk → Document, no notification
        │
        └─ Breach Identified → Notification Required
            │
            ├─ < 500 individuals: Annual notification to HHS
            ├─ ≥ 500 individuals: 60-day notification to HHS + media
            └─ All cases: Individual notification within 60 days
```

### Notification Templates

#### Individual Notification Letter

```
[Date]

Dear [Individual Name],

We are writing to notify you of a data security incident that may have involved some of your protected health information (PHI).

What Happened:
[Brief description of incident]

What Information Was Involved:
[Specific data elements affected]

What We Are Doing:
[Steps taken to investigate and prevent recurrence]

What You Can Do:
[Recommended actions for affected individuals]

For More Information:
Contact our Privacy Officer at:
Phone: (XXX) XXX-XXXX
Email: privacy@healthcare-corp.com

We sincerely regret any inconvenience or concern this matter may cause you.

Sincerely,
[Privacy Officer Name]
Chief Privacy Officer
```

#### HHS Notification (≥500 individuals)

```yaml
HHS Breach Notification Portal Submission:
  
  Covered Entity Information:
    Name: Healthcare Corporation
    Address: [Full address]
    Phone: [Phone number]
    Website: www.healthcare-corp.com
  
  Breach Information:
    Type of Breach: Unauthorized Access/Hacking
    Location: Cloud Data Warehouse (BigQuery)
    Business Associate Involved: [If applicable]
    
  Discovery and Notification:
    Date Discovered: [Date]
    Date Individuals Notified: [Date]
    
  Individuals Affected:
    Number: [Number ≥ 500]
    State: [State(s) affected]
    
  PHI Involved:
    Types: [List of data elements]
    
  Breach Description:
    [Detailed narrative]
    
  Safeguards in Place:
    [Description of security measures]
```

### Post-Breach Actions

```yaml
Breach Response Checklist:
  
  Immediate (0-24 hours):
    - [ ] Contain the breach
    - [ ] Preserve evidence
    - [ ] Notify leadership
    - [ ] Engage legal counsel
    - [ ] Begin investigation
  
  Short-term (1-7 days):
    - [ ] Complete risk assessment
    - [ ] Determine notification requirements
    - [ ] Draft notification letters
    - [ ] Prepare HHS submission
    - [ ] Engage PR if needed
  
  Medium-term (7-60 days):
    - [ ] Notify affected individuals (within 60 days)
    - [ ] Submit to HHS (within 60 days)
    - [ ] Media notification if ≥500 (within 60 days)
    - [ ] Update policies/procedures
    - [ ] Implement additional safeguards
  
  Long-term (60+ days):
    - [ ] Complete investigation
    - [ ] Post-incident review
    - [ ] Update training materials
    - [ ] Monitor for identity theft
    - [ ] Annual HHS reporting (if <500)
```

---

**Document Version**: 2.0  
**Last Updated**: February 2026  
**Next Review**: May 2026  
**Classification**: Confidential - Compliance Use  
**Owner**: Legal & Compliance Team  
**Approved By**: Chief Compliance Officer
