# Privacy Impact Assessment (PIA) Template
## Hadoop to BigQuery Migration Project

**Document Classification:** Confidential  
**Assessment Date:** February 2026  
**Next Review Date:** February 2027  
**Assessment Team:** Legal, Compliance, Security, Data Engineering

---

## Executive Summary

### Assessment Overview

This Privacy Impact Assessment (PIA) evaluates the privacy risks associated with the migration of healthcare data from an on-premises Hadoop cluster to Google Cloud Platform's BigQuery data warehouse. The assessment examines data flows, privacy controls, and compliance with applicable regulations including HIPAA and state privacy laws.

**Key Findings:**
- **Overall Risk Rating:** Low (after mitigation)
- **Critical Controls Implemented:** 15
- **Outstanding Risks:** 0 critical, 2 medium (with mitigation plans)
- **Compliance Status:** Full HIPAA compliance achieved

---

## Section 1: Project Description

### 1.1 Project Purpose

**Primary Objectives:**
- Modernize data infrastructure for improved analytics capabilities
- Reduce operational costs and maintenance burden
- Improve query performance and scalability
- Enable advanced machine learning capabilities
- Enhance data governance and compliance posture

**Business Justification:**
The migration enables real-time analytics, predictive modeling, and improved clinical decision support while reducing infrastructure costs by 68% and improving query performance by 73%.

### 1.2 System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│ Data Migration System Architecture                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Source System:                                                  │
│  ├─ On-Premises Hadoop Cluster (HDFS)                          │
│  ├─ 12.5 TB of healthcare data                                 │
│  ├─ 85 tables with PHI/PII data                                │
│  └─ 240 million patient records                                │
│                                                                   │
│  Target System:                                                  │
│  ├─ Google Cloud BigQuery                                       │
│  ├─ Multi-region deployment (US)                               │
│  ├─ Customer-managed encryption keys                           │
│  └─ VPC Service Controls enabled                               │
│                                                                   │
│  Processing Layer:                                               │
│  ├─ Cloud Dataflow (Apache Beam)                               │
│  ├─ Cloud DLP (Data Loss Prevention)                           │
│  ├─ Field-level encryption/masking                             │
│  └─ Automated validation pipelines                             │
└─────────────────────────────────────────────────────────────────┘
```

### 1.3 Stakeholders

| Role | Name | Responsibilities |
|------|------|------------------|
| **Project Sponsor** | Chief Data Officer | Executive oversight, budget approval |
| **Privacy Officer** | Chief Privacy Officer | Privacy compliance, PIA approval |
| **Security Officer** | Chief Information Security Officer | Security controls, risk management |
| **Data Owner** | VP of Clinical Operations | Data stewardship, access decisions |
| **Technical Lead** | Senior Data Engineer | Implementation, technical controls |
| **Compliance Lead** | Director of Compliance | Regulatory compliance, audit coordination |

---

## Section 2: Data Inventory

### 2.1 Protected Health Information (PHI)

#### Direct Identifiers

| Data Element | Source Tables | Volume | Sensitivity | Masking Applied |
|--------------|--------------|--------|-------------|-----------------|
| **Patient Names** | patients, encounters | 15M records | High | Pseudonymization |
| **Social Security Numbers** | patients, billing | 15M records | Critical | Tokenization (FFX) |
| **Medical Record Numbers** | patients, encounters | 15M records | High | Tokenization |
| **Email Addresses** | patients, communications | 12M records | Medium | Redaction |
| **Phone Numbers** | patients, contacts | 14M records | Medium | Partial masking |
| **Physical Addresses** | patients, providers | 15M records | Medium | ZIP code only |
| **Dates of Birth** | patients | 15M records | Medium | Date shifting |
| **IP Addresses** | audit_logs | 50M records | Low | Hashing |

#### Quasi-Identifiers

| Data Element | Risk Level | Mitigation Strategy |
|--------------|-----------|---------------------|
| **Admission/Discharge Dates** | Medium | Date shifting (±180 days) |
| **Diagnosis Codes** | Low | No masking (aggregation only) |
| **Procedure Codes** | Low | No masking (aggregation only) |
| **Provider ZIP Codes** | Medium | Generalization to 3-digit |
| **Age Ranges** | Low | 5-year bins for >90 years old |
| **Gender** | Low | No masking (retain for analysis) |

#### Special Categories of PHI

```yaml
Highly Sensitive Data:
  
  Mental Health Records:
    Tables: mental_health_encounters, psychiatric_meds
    Records: 2.5M
    Additional Controls:
      - Separate dataset with stricter access
      - Additional encryption layer
      - Audit all access (no exceptions)
  
  Substance Abuse Treatment:
    Tables: substance_abuse_treatment
    Records: 800K
    Additional Controls:
      - 42 CFR Part 2 compliance
      - Written consent required for access
      - Extra audit logging
  
  HIV Status:
    Tables: lab_results, diagnoses
    Records: 150K
    Additional Controls:
      - State law compliance (varies by state)
      - Column-level security
      - Redacted in most views
  
  Genetic Information:
    Tables: genetic_tests, genomic_data
    Records: 50K
    Additional Controls:
      - GINA compliance
      - Extremely restricted access
      - Separate encryption key
```

### 2.2 Non-PHI Data

| Data Category | Description | Privacy Risk | Controls |
|--------------|-------------|--------------|----------|
| **Clinical Reference Data** | Diagnosis codes, drug catalogs | None | Public data |
| **Operational Metadata** | Table schemas, pipeline configs | Low | Standard access control |
| **Aggregated Analytics** | De-identified statistics | Low | Aggregation thresholds (≥11) |

---

## Section 3: Privacy Risk Assessment

### 3.1 Risk Identification

#### Risk Assessment Matrix

```
┌─────────────────────────────────────────────────────────────────┐
│ Privacy Risk Heat Map                                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│              LIKELIHOOD                                          │
│              ↓                                                   │
│       │ 1  │ 2  │ 3  │ 4  │ 5  │                              │
│   ────┼────┼────┼────┼────┼────┤                              │
│   5   │ M  │ H  │ H  │ C  │ C  │  I                            │
│   ────┼────┼────┼────┼────┼────┤  M                            │
│   4   │ M  │ M  │ H  │ H  │ C  │  P                            │
│   ────┼────┼────┼────┼────┼────┤  A                            │
│   3   │ L  │ M  │ M  │ H  │ H  │  C                            │
│   ────┼────┼────┼────┼────┼────┤  T                            │
│   2   │ L  │ L  │ M  │ M  │ H  │  →                            │
│   ────┼────┼────┼────┼────┼────┤                              │
│   1   │ L  │ L  │ L  │ M  │ M  │                              │
│   ────┴────┴────┴────┴────┴────┘                              │
│                                                                   │
│   L = Low Risk (1-5)                                            │
│   M = Medium Risk (6-12)                                        │
│   H = High Risk (13-20)                                         │
│   C = Critical Risk (21-25)                                     │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 Identified Privacy Risks

#### Critical & High Risks (Mitigated)

| Risk ID | Risk Description | Likelihood (pre) | Impact | Risk Score (pre) | Mitigation | Residual Risk |
|---------|-----------------|------------------|--------|------------------|------------|---------------|
| **PR-001** | Unauthorized access to PHI during transit | 3 | 5 | 15 (High) | TLS 1.3, VPN encryption, VPC Service Controls | 1x2=2 (Low) |
| **PR-002** | Data breach in cloud storage | 2 | 5 | 10 (Medium) | CMEK encryption, access controls, DLP monitoring | 1x3=3 (Low) |
| **PR-003** | Re-identification of masked data | 2 | 4 | 8 (Medium) | K-anonymity testing, multiple masking layers | 1x2=2 (Low) |
| **PR-004** | Insider threat/malicious access | 2 | 5 | 10 (Medium) | IAM, audit logging, UEBA, least privilege | 1x3=3 (Low) |
| **PR-005** | Insufficient de-identification | 3 | 4 | 12 (Medium) | DLP validation, expert review, testing | 1x2=2 (Low) |

#### Medium Risks

| Risk ID | Risk Description | Current Controls | Residual Risk | Action Plan |
|---------|-----------------|------------------|---------------|-------------|
| **PR-006** | Third-party subprocessor risk | BAA, contractual controls | 2x3=6 | Annual audits, ongoing monitoring |
| **PR-007** | Incomplete audit trails | Comprehensive logging | 1x3=3 | Log completeness validation |
| **PR-008** | Key management failure | KMS, automated rotation | 1x4=4 | Regular DR testing |

#### Low Risks (Accepted)

| Risk ID | Risk Description | Justification |
|---------|-----------------|---------------|
| **PR-009** | Metadata disclosure | Metadata doesn't contain PHI, minimal privacy impact |
| **PR-010** | Performance logging | Logs sanitized, no PHI included |
| **PR-011** | Service outage | Impacts availability, not confidentiality |

### 3.3 Data Flow Analysis

```
┌─────────────────────────────────────────────────────────────────┐
│ PHI Data Flow with Privacy Controls                             │
└─────────────────────────────────────────────────────────────────┘

[Hadoop HDFS]
    │ PHI in clear text
    │ (within corporate network)
    ▼
[Cloud VPN/Interconnect] ◄────── Control: TLS 1.3 encryption
    │ PHI encrypted in transit
    ▼
[GCS Staging Bucket] ◄────────── Control: CMEK encryption at rest
    │ PHI encrypted but not masked
    ▼
[Cloud Dataflow Pipeline]
    │
    ├─► [DLP Inspection] ◄────── Control: PII/PHI detection
    │       │
    │       ▼
    ├─► [Masking Transforms] ◄── Control: Tokenization, pseudonymization
    │       │
    │       ▼
    └─► [Validation] ◄─────────── Control: Quality checks, re-identification testing
        │
        ▼
[BigQuery - Masked Dataset] ◄─── Control: Row/column security, authorized views
    │ PHI masked, encrypted
    │
    ├─► [Analytics Views] ◄───── Control: Aggregation (k≥11), role-based access
    │
    └─► [Audit Logs] ◄────────── Control: 7-year retention, immutable
```

---

## Section 4: Privacy Controls

### 4.1 Technical Controls

#### Encryption

```yaml
Encryption at Rest:
  Technology: Customer-Managed Encryption Keys (CMEK)
  Algorithm: AES-256-GCM
  Key Management: Cloud KMS with HSM
  Key Rotation: Automatic (90 days)
  Key Access: Strictly controlled via IAM
  Effectiveness: Prevents unauthorized access to data at rest
  
Encryption in Transit:
  Technology: TLS 1.3
  Cipher Suites: Strong ciphers only (AES-GCM, ChaCha20)
  Certificate Management: Automated renewal
  Perfect Forward Secrecy: Enabled
  Effectiveness: Prevents eavesdropping and MITM attacks
  
Field-Level Encryption:
  Technology: Application-layer encryption via Cloud KMS
  Use Cases: Highly sensitive fields (SSN, genetic data)
  Algorithm: AES-256-GCM
  Key Separation: Unique keys per data type
  Effectiveness: Defense in depth, granular protection
```

#### De-identification

```yaml
Masking Techniques:
  
  Tokenization:
    Method: Format-Preserving Encryption (FFX)
    Fields: SSN, MRN, Credit Cards
    Reversibility: Yes (with key)
    Format Preservation: Yes
    Effectiveness: Maintains utility while preventing re-identification
  
  Pseudonymization:
    Method: HMAC-SHA256 with secret key
    Fields: Patient names, provider names
    Reversibility: No (one-way hash)
    Deterministic: Yes (same input → same output)
    Effectiveness: Enables linkage while preventing identification
  
  Generalization:
    Method: Value substitution with broader category
    Fields: ZIP codes (5→3 digit), Ages (>90→90+)
    Reversibility: No
    Effectiveness: Reduces re-identification risk for quasi-identifiers
  
  Date Shifting:
    Method: Consistent random shift per patient (±180 days)
    Fields: Dates (except year)
    Reversibility: No
    Deterministic: Yes per patient
    Effectiveness: Maintains temporal relationships while masking
```

#### Access Controls

```yaml
Identity and Access Management:
  
  Authentication:
    - Multi-Factor Authentication (MFA) required
    - Google SSO integration
    - Service account authentication via Workload Identity
  
  Authorization:
    - Role-Based Access Control (RBAC)
    - Least privilege principle
    - Custom roles for healthcare data
    - Automated access reviews (quarterly)
  
  Row-Level Security:
    - BigQuery policy tags
    - Conditional access based on user attributes
    - Dynamic data masking based on role
  
  Column-Level Security:
    - Sensitive columns restricted by default
    - Authorized views for controlled access
    - Automatic redaction for unauthorized users
```

### 4.2 Administrative Controls

```yaml
Policies and Procedures:
  
  Data Access Policy:
    - Minimum necessary standard
    - Business justification required
    - Manager approval workflow
    - Time-limited access (90-day default)
  
  Data Handling Procedures:
    - PHI must remain in approved environments
    - No PHI on workstations without encryption
    - Secure disposal procedures
    - Data retention schedules
  
  Incident Response Plan:
    - 15-minute response time for P0 incidents
    - Breach notification procedures
    - Forensic investigation capabilities
    - Post-incident review process
  
  Training Requirements:
    - Initial HIPAA training (4 hours)
    - Annual refresher (2 hours)
    - Role-specific training
    - Quarterly phishing simulations
```

### 4.3 Organizational Controls

```yaml
Governance Structure:
  
  Privacy Office:
    - Chief Privacy Officer (dedicated role)
    - Privacy team (3 FTE)
    - Reporting to Chief Legal Officer
  
  Data Governance Council:
    - Quarterly meetings
    - Cross-functional membership
    - Data classification authority
    - Policy approval authority
  
  Security Operations:
    - 24/7 SOC monitoring
    - SIEM integration
    - Incident response team
    - Regular security assessments
  
  Compliance Program:
    - Annual HIPAA audits
    - Quarterly internal audits
    - Continuous compliance monitoring
    - Regulatory change management
```

---

## Section 5: Compliance Analysis

### 5.1 Regulatory Requirements

#### HIPAA Compliance

```
✅ Privacy Rule (45 CFR 164.500-.534):
   ├─ Minimum necessary standard applied
   ├─ Individual rights procedures documented
   ├─ Notice of Privacy Practices updated
   └─ Business Associate Agreements executed

✅ Security Rule (45 CFR 164.302-.318):
   ├─ Administrative safeguards implemented
   ├─ Physical safeguards (GCP data centers)
   ├─ Technical safeguards (encryption, access control)
   └─ Policies and procedures documented

✅ Breach Notification Rule (45 CFR 164.400-.414):
   ├─ Breach assessment procedures
   ├─ Notification templates prepared
   ├─ 60-day notification capability
   └─ HHS reporting process documented
```

#### State Privacy Laws

| State | Law | Applicability | Compliance Status |
|-------|-----|---------------|-------------------|
| **California** | CCPA/CPRA | Patient residents | ✅ Compliant |
| **New York** | SHIELD Act | Patient residents | ✅ Compliant |
| **Texas** | Medical Privacy | Providers in TX | ✅ Compliant |
| **All States** | State Breach Laws | Various triggers | ✅ Procedures in place |

### 5.2 Industry Standards

```yaml
Standards Compliance:
  
  NIST Cybersecurity Framework:
    Identify: ✅ Asset inventory, risk assessment
    Protect: ✅ Access control, encryption, training
    Detect: ✅ Continuous monitoring, anomaly detection
    Respond: ✅ Incident response plan, communication
    Recover: ✅ Recovery planning, improvements
  
  ISO 27001:
    Information Security Management: ✅ ISMS implemented
    Risk Assessment: ✅ Annual assessments
    Control Objectives: ✅ 114 controls implemented
  
  HITRUST CSF:
    Status: In progress (certification Q3 2026)
    Maturity Level: Level 3 (Advanced)
    Gaps: 3 minor gaps identified (remediation underway)
```

---

## Section 6: Testing and Validation

### 6.1 Re-identification Testing

```yaml
K-Anonymity Testing:
  
  Methodology:
    - Quasi-identifier analysis
    - Uniqueness testing
    - Linkage attack simulation
    - Expert review
  
  Results:
    Date: January 2026
    Sample Size: 100,000 records
    K-Value Achieved: K ≥ 11 (exceeds target of K ≥ 5)
    Findings: No unique records identified
    Reviewer: External privacy expert
    
  Quasi-Identifiers Tested:
    - ZIP code (3-digit)
    - Age (5-year bins for >90)
    - Gender
    - Admission year
    
  Conclusion: Low risk of re-identification
```

### 6.2 Security Testing

```yaml
Penetration Testing:
  
  External Testing (Q4 2025):
    Scope: External perimeter, VPN, public endpoints
    Duration: 2 weeks
    Findings:
      - 0 Critical
      - 0 High
      - 1 Medium (remediated)
      - 3 Low (accepted)
  
  Internal Testing (Q4 2025):
    Scope: IAM, data access, privilege escalation
    Duration: 1 week
    Findings:
      - 0 Critical
      - 1 High (remediated)
      - 2 Medium (remediated)
  
  Application Testing:
    Scope: Dataflow pipelines, custom applications
    Duration: 1 week
    Findings:
      - 0 Critical
      - 1 Medium (remediated)
```

### 6.3 Compliance Testing

```yaml
Audit Program:
  
  Internal Audits (Quarterly):
    Q4 2025 Results:
      - Access control review: ✅ Pass
      - Encryption validation: ✅ Pass
      - Audit log completeness: ✅ Pass
      - Training compliance: ⚠️ 98% (target 100%)
  
  External Audit (Annual):
    Provider: Independent HIPAA auditor
    Date: November 2025
    Scope: Full HIPAA Security Rule
    Result: ✅ Compliant
    Findings: 0 critical, 2 minor (remediated)
  
  Continuous Monitoring:
    - Automated compliance checks (daily)
    - Configuration drift detection
    - Policy violation alerts
    - Real-time dashboards
```

---

## Section 7: Recommendations and Action Items

### 7.1 Current Action Items

| ID | Action | Priority | Owner | Due Date | Status |
|----|--------|----------|-------|----------|--------|
| **A-001** | Complete training for 2% non-compliant staff | High | HR | 2026-03-01 | In Progress |
| **A-002** | Enhance monitoring for mental health data access | Medium | Security | 2026-03-15 | Planned |
| **A-003** | Document data retention procedures | Medium | Compliance | 2026-02-28 | In Progress |
| **A-004** | Conduct HITRUST certification assessment | Medium | Compliance | 2026-09-30 | Planned |
| **A-005** | Review and update privacy notices | Low | Legal | 2026-04-30 | Planned |

### 7.2 Long-term Recommendations

```markdown
## Strategic Recommendations (12-24 months)

1. **Advanced Privacy Technologies**
   - Evaluate differential privacy for analytics
   - Implement homomorphic encryption for computation on encrypted data
   - Explore federated learning for ML models

2. **Enhanced Governance**
   - Implement automated data lineage tracking
   - Deploy AI-powered anomaly detection
   - Enhance data quality monitoring

3. **Expanded Training**
   - Develop role-specific simulation exercises
   - Create privacy champions program
   - Implement gamified training modules

4. **Technology Upgrades**
   - Evaluate Confidential Computing (AMD SEV, Intel SGX)
   - Implement Privacy-Preserving Record Linkage (PPRL)
   - Enhance tokenization with Vault integration
```

---

## Section 8: Conclusion

### 8.1 PIA Summary

This Privacy Impact Assessment has evaluated the privacy risks associated with migrating healthcare data from an on-premises Hadoop environment to Google Cloud Platform's BigQuery. Through comprehensive analysis, we have:

**Achievements:**
1. ✅ Identified all PHI data elements and flows
2. ✅ Assessed privacy risks across likelihood and impact dimensions
3. ✅ Implemented robust technical, administrative, and organizational controls
4. ✅ Achieved full HIPAA compliance
5. ✅ Validated de-identification effectiveness (K ≥ 11)
6. ✅ Established continuous monitoring and audit procedures

**Risk Posture:**
- **Pre-mitigation:** 5 high/critical risks identified
- **Post-mitigation:** 0 critical, 2 medium, 6 low risks remain
- **Overall Risk Rating:** LOW (acceptable with ongoing monitoring)

### 8.2 Privacy Office Determination

**Assessment:** APPROVED  
**Effective Date:** February 1, 2026  
**Next Review:** February 1, 2027 (or sooner if material changes occur)

**Conditions:**
1. Complete all action items within specified timelines
2. Maintain all documented controls
3. Conduct quarterly access reviews
4. Report any privacy incidents within 24 hours
5. Update this PIA if material changes occur

**Signatures:**

___________________________________  
Chief Privacy Officer  
Date: February 1, 2026

___________________________________  
Chief Information Security Officer  
Date: February 1, 2026

___________________________________  
Chief Compliance Officer  
Date: February 1, 2026

---

## Appendices

### Appendix A: Glossary

| Term | Definition |
|------|------------|
| **De-identification** | Process of removing identifying information from data |
| **K-anonymity** | Privacy model where each record is indistinguishable from at least K-1 other records |
| **PHI** | Protected Health Information under HIPAA |
| **Quasi-identifier** | Attribute that can contribute to re-identification when combined with other data |
| **Tokenization** | Replacing sensitive data with non-sensitive equivalent |

### Appendix B: Data Dictionary

[Detailed table schemas and data element definitions - 85 tables documented]

### Appendix C: Risk Register

[Complete risk register with all identified risks, controls, and monitoring procedures]

### Appendix D: Audit Reports

[External audit reports, penetration test reports, compliance assessments]

---

**Document Control:**
- Version: 1.0
- Classification: Confidential
- Retention: 7 years after system decommission
- Distribution: Legal, Compliance, Security, Privacy Office
