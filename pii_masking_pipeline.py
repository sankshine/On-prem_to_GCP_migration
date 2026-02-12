"""
PII/PHI Data Masking Pipeline
Healthcare Data Migration: Hadoop to BigQuery

This Apache Beam pipeline implements comprehensive PII/PHI detection and masking
using Cloud DLP and custom transformation logic.

Author: Healthcare Data Engineering Team
Compliance: HIPAA/PHI Requirements
"""

import apache_beam as beam
from apache_beam.options.pipeline_options import PipelineOptions, StandardOptions
from apache_beam.io import ReadFromText, WriteToText
from apache_beam.io.gcp.bigquery import WriteToBigQuery, BigQueryDisposition
from google.cloud import dlp_v2
from google.cloud import kms
import json
import hashlib
import hmac
from datetime import datetime, timedelta
import logging
import re
from typing import Dict, List, Any, Optional

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class PIIDetectionConfig:
    """Configuration for PII/PHI detection"""
    
    # DLP info types to detect
    INFO_TYPES = [
        'US_SOCIAL_SECURITY_NUMBER',
        'EMAIL_ADDRESS',
        'PHONE_NUMBER',
        'PERSON_NAME',
        'DATE_OF_BIRTH',
        'US_DRIVERS_LICENSE_NUMBER',
        'CREDIT_CARD_NUMBER',
        'MEDICAL_RECORD_NUMBER',
        'US_HEALTHCARE_NPI',
        'IP_ADDRESS',
        'LOCATION'
    ]
    
    # Minimum likelihood for detection
    MIN_LIKELIHOOD = dlp_v2.Likelihood.POSSIBLE
    
    # Custom patterns for healthcare-specific data
    CUSTOM_PATTERNS = {
        'MEDICAL_RECORD_NUMBER': r'MRN[0-9]{8}',
        'PATIENT_ID': r'PID[0-9]{10}',
        'ENCOUNTER_ID': r'ENC[0-9]{12}'
    }


class MaskingStrategies:
    """Different masking strategies for various data types"""
    
    @staticmethod
    def tokenize_ssn(ssn: str, crypto_key: str) -> str:
        """
        Tokenize SSN using format-preserving encryption
        
        Args:
            ssn: Social Security Number
            crypto_key: Encryption key from Cloud KMS
            
        Returns:
            Tokenized SSN maintaining format
        """
        # Remove hyphens
        ssn_clean = ssn.replace('-', '')
        
        # Simple format-preserving tokenization (production would use FFX)
        token = hashlib.sha256(f"{crypto_key}{ssn_clean}".encode()).hexdigest()[:9]
        token_formatted = f"{token[:3]}-{token[3:5]}-{token[5:]}"
        
        logger.info(f"Tokenized SSN")
        return token_formatted
    
    @staticmethod
    def pseudonymize_name(name: str, secret_key: str) -> str:
        """
        Create deterministic pseudonym for names
        
        Args:
            name: Person's name
            secret_key: Secret key for HMAC
            
        Returns:
            Pseudonymized name
        """
        hmac_obj = hmac.new(
            secret_key.encode('utf-8'),
            name.encode('utf-8'),
            hashlib.sha256
        )
        hash_value = hmac_obj.hexdigest()[:8]
        pseudonym = f"PATIENT_{hash_value.upper()}"
        
        logger.info(f"Pseudonymized name")
        return pseudonym
    
    @staticmethod
    def mask_email(email: str) -> str:
        """
        Mask email address preserving domain
        
        Args:
            email: Email address
            
        Returns:
            Masked email
        """
        try:
            username, domain = email.split('@')
            if len(username) > 1:
                masked_username = username[0] + '*' * (len(username) - 1)
            else:
                masked_username = '*'
            return f"{masked_username}@{domain}"
        except ValueError:
            return "***@***.com"
    
    @staticmethod
    def mask_phone(phone: str) -> str:
        """
        Mask phone number keeping only last 4 digits
        
        Args:
            phone: Phone number
            
        Returns:
            Masked phone number
        """
        digits = re.sub(r'\D', '', phone)
        if len(digits) >= 4:
            return f"***-***-{digits[-4:]}"
        return "***-***-****"
    
    @staticmethod
    def shift_date(date_str: str, patient_id: str, shift_range: int = 365) -> str:
        """
        Shift dates consistently per patient
        
        Args:
            date_str: Date string in YYYY-MM-DD format
            patient_id: Patient identifier for consistent shifting
            shift_range: Maximum days to shift (+/-)
            
        Returns:
            Shifted date string
        """
        try:
            # Use patient ID as seed for consistent shifting
            seed = int(hashlib.md5(patient_id.encode()).hexdigest(), 16) % (2 * shift_range)
            shift_days = seed - shift_range
            
            # Parse and shift date
            original_date = datetime.strptime(date_str, '%Y-%m-%d')
            shifted_date = original_date + timedelta(days=shift_days)
            
            return shifted_date.strftime('%Y-%m-%d')
        except (ValueError, TypeError):
            return date_str
    
    @staticmethod
    def mask_address(address: str) -> str:
        """
        Mask address keeping only ZIP code
        
        Args:
            address: Full address
            
        Returns:
            Masked address with ZIP code only
        """
        # Extract ZIP code (5 or 9 digits)
        zip_match = re.search(r'\b\d{5}(?:-\d{4})?\b', address)
        if zip_match:
            return f"*****, ** {zip_match.group()}"
        return "*****, ** *****"


class DetectPIIFn(beam.DoFn):
    """DoFn to detect PII/PHI using Cloud DLP"""
    
    def __init__(self, project_id: str, dlp_template: str):
        self.project_id = project_id
        self.dlp_template = dlp_template
        self.dlp_client = None
    
    def setup(self):
        """Initialize DLP client"""
        self.dlp_client = dlp_v2.DlpServiceClient()
    
    def process(self, element: Dict[str, Any]) -> List[Dict[str, Any]]:
        """
        Detect PII/PHI in record
        
        Args:
            element: Record dictionary
            
        Yields:
            Record with PII detection results
        """
        try:
            # Convert record to string for inspection
            record_str = json.dumps(element)
            
            # Prepare DLP request
            item = {'value': record_str}
            
            # Call DLP API
            response = self.dlp_client.inspect_content(
                request={
                    'parent': f'projects/{self.project_id}',
                    'inspect_template_name': self.dlp_template,
                    'item': item
                }
            )
            
            # Extract findings
            findings = []
            for finding in response.result.findings:
                findings.append({
                    'info_type': finding.info_type.name,
                    'likelihood': finding.likelihood.name,
                    'quote': finding.quote if hasattr(finding, 'quote') else '',
                    'location': str(finding.location) if hasattr(finding, 'location') else ''
                })
            
            # Add findings to record
            element['_pii_findings'] = findings
            element['_pii_detected'] = len(findings) > 0
            
            logger.info(f"Detected {len(findings)} PII findings in record")
            
            yield element
            
        except Exception as e:
            logger.error(f"Error detecting PII: {str(e)}")
            element['_pii_error'] = str(e)
            yield element


class MaskPIIFn(beam.DoFn):
    """DoFn to mask detected PII/PHI"""
    
    def __init__(self, crypto_key: str, secret_key: str):
        self.crypto_key = crypto_key
        self.secret_key = secret_key
        self.masking = MaskingStrategies()
    
    def process(self, element: Dict[str, Any]) -> List[Dict[str, Any]]:
        """
        Apply masking to detected PII fields
        
        Args:
            element: Record with PII detection results
            
        Yields:
            Masked record
        """
        try:
            # Get PII findings
            findings = element.get('_pii_findings', [])
            
            if not findings:
                yield element
                return
            
            # Apply appropriate masking based on field type
            masked_record = element.copy()
            
            for field_name, field_value in element.items():
                if field_name.startswith('_'):
                    continue
                
                # Determine field type and apply masking
                if isinstance(field_value, str):
                    # Check if field contains PII
                    for finding in findings:
                        info_type = finding['info_type']
                        
                        if info_type == 'US_SOCIAL_SECURITY_NUMBER' and 'ssn' in field_name.lower():
                            masked_record[field_name] = self.masking.tokenize_ssn(
                                field_value, self.crypto_key
                            )
                            masked_record[f'{field_name}_masked'] = True
                        
                        elif info_type == 'PERSON_NAME' and any(x in field_name.lower() for x in ['name', 'patient', 'provider']):
                            masked_record[field_name] = self.masking.pseudonymize_name(
                                field_value, self.secret_key
                            )
                            masked_record[f'{field_name}_masked'] = True
                        
                        elif info_type == 'EMAIL_ADDRESS' and 'email' in field_name.lower():
                            masked_record[field_name] = self.masking.mask_email(field_value)
                            masked_record[f'{field_name}_masked'] = True
                        
                        elif info_type == 'PHONE_NUMBER' and 'phone' in field_name.lower():
                            masked_record[field_name] = self.masking.mask_phone(field_value)
                            masked_record[f'{field_name}_masked'] = True
                        
                        elif info_type == 'DATE_OF_BIRTH' and 'dob' in field_name.lower():
                            patient_id = element.get('patient_id', field_name)
                            masked_record[field_name] = self.masking.shift_date(
                                field_value, patient_id
                            )
                            masked_record[f'{field_name}_masked'] = True
                        
                        elif info_type == 'LOCATION' and 'address' in field_name.lower():
                            masked_record[field_name] = self.masking.mask_address(field_value)
                            masked_record[f'{field_name}_masked'] = True
            
            # Add masking metadata
            masked_record['_masking_timestamp'] = datetime.now().isoformat()
            masked_record['_fields_masked'] = [
                k for k in masked_record.keys() if k.endswith('_masked')
            ]
            
            # Remove detection metadata before output
            for key in ['_pii_findings', '_pii_detected', '_pii_error']:
                masked_record.pop(key, None)
            
            logger.info(f"Masked {len(masked_record['_fields_masked'])} fields")
            
            yield masked_record
            
        except Exception as e:
            logger.error(f"Error masking PII: {str(e)}")
            element['_masking_error'] = str(e)
            yield element


class ValidateDataQualityFn(beam.DoFn):
    """DoFn to validate data quality post-masking"""
    
    def __init__(self, required_fields: List[str]):
        self.required_fields = required_fields
    
    def process(self, element: Dict[str, Any]) -> List[Dict[str, Any]]:
        """
        Validate data quality
        
        Args:
            element: Masked record
            
        Yields:
            Valid records
        """
        try:
            # Check required fields
            missing_fields = [f for f in self.required_fields if f not in element]
            
            if missing_fields:
                logger.warning(f"Missing required fields: {missing_fields}")
                element['_validation_error'] = f"Missing fields: {missing_fields}"
                element['_validation_status'] = 'FAILED'
            else:
                element['_validation_status'] = 'PASSED'
            
            # Check for null/empty values
            null_fields = [k for k, v in element.items() if v is None or v == '']
            if null_fields:
                element['_null_fields'] = null_fields
            
            # Add validation timestamp
            element['_validation_timestamp'] = datetime.now().isoformat()
            
            yield element
            
        except Exception as e:
            logger.error(f"Error validating data: {str(e)}")
            element['_validation_error'] = str(e)
            yield element


def run_pii_masking_pipeline(
    project_id: str,
    input_path: str,
    output_table: str,
    dlp_template: str,
    crypto_key: str,
    secret_key: str,
    required_fields: List[str],
    pipeline_args: List[str]
) -> None:
    """
    Execute PII masking pipeline
    
    Args:
        project_id: GCP project ID
        input_path: GCS path to input data
        output_table: BigQuery output table
        dlp_template: DLP inspection template name
        crypto_key: KMS encryption key
        secret_key: Secret key for pseudonymization
        required_fields: List of required fields for validation
        pipeline_args: Additional pipeline arguments
    """
    
    # Set up pipeline options
    pipeline_options = PipelineOptions(pipeline_args)
    pipeline_options.view_as(StandardOptions).streaming = False
    
    # Define BigQuery schema
    table_schema = {
        'fields': [
            {'name': 'patient_id', 'type': 'STRING', 'mode': 'REQUIRED'},
            {'name': 'patient_name', 'type': 'STRING', 'mode': 'NULLABLE'},
            {'name': 'ssn', 'type': 'STRING', 'mode': 'NULLABLE'},
            {'name': 'email', 'type': 'STRING', 'mode': 'NULLABLE'},
            {'name': 'phone', 'type': 'STRING', 'mode': 'NULLABLE'},
            {'name': 'date_of_birth', 'type': 'DATE', 'mode': 'NULLABLE'},
            {'name': 'address', 'type': 'STRING', 'mode': 'NULLABLE'},
            {'name': '_masking_timestamp', 'type': 'TIMESTAMP', 'mode': 'NULLABLE'},
            {'name': '_fields_masked', 'type': 'STRING', 'mode': 'REPEATED'},
            {'name': '_validation_status', 'type': 'STRING', 'mode': 'NULLABLE'},
            {'name': '_validation_timestamp', 'type': 'TIMESTAMP', 'mode': 'NULLABLE'},
        ]
    }
    
    # Create pipeline
    with beam.Pipeline(options=pipeline_options) as pipeline:
        
        # Read input data
        records = (
            pipeline
            | 'Read from GCS' >> ReadFromText(input_path)
            | 'Parse JSON' >> beam.Map(json.loads)
        )
        
        # Detect PII
        pii_detected = (
            records
            | 'Detect PII' >> beam.ParDo(DetectPIIFn(project_id, dlp_template))
        )
        
        # Mask PII
        pii_masked = (
            pii_detected
            | 'Mask PII' >> beam.ParDo(MaskPIIFn(crypto_key, secret_key))
        )
        
        # Validate data quality
        validated = (
            pii_masked
            | 'Validate Quality' >> beam.ParDo(ValidateDataQualityFn(required_fields))
        )
        
        # Write to BigQuery
        _ = (
            validated
            | 'Write to BigQuery' >> WriteToBigQuery(
                output_table,
                schema=table_schema,
                write_disposition=BigQueryDisposition.WRITE_APPEND,
                create_disposition=BigQueryDisposition.CREATE_IF_NEEDED
            )
        )
        
        # Write validation metrics
        validation_metrics = (
            validated
            | 'Extract Status' >> beam.Map(lambda x: x.get('_validation_status', 'UNKNOWN'))
            | 'Count by Status' >> beam.combiners.Count.PerElement()
            | 'Format Metrics' >> beam.Map(lambda x: f"{x[0]}: {x[1]}")
        )
        
        _ = (
            validation_metrics
            | 'Write Metrics' >> WriteToText(
                f'{input_path}_validation_metrics',
                file_name_suffix='.txt'
            )
        )
    
    logger.info("PII masking pipeline completed successfully")


if __name__ == '__main__':
    """Main entry point for pipeline execution"""
    
    import argparse
    
    parser = argparse.ArgumentParser(description='PII/PHI Masking Pipeline')
    parser.add_argument('--project_id', required=True, help='GCP Project ID')
    parser.add_argument('--input_path', required=True, help='Input GCS path')
    parser.add_argument('--output_table', required=True, help='Output BigQuery table')
    parser.add_argument('--dlp_template', required=True, help='DLP template name')
    parser.add_argument('--crypto_key', required=True, help='KMS crypto key')
    parser.add_argument('--secret_key', required=True, help='Secret key for HMAC')
    parser.add_argument('--required_fields', required=True, help='Comma-separated required fields')
    
    args, pipeline_args = parser.parse_known_args()
    
    # Parse required fields
    required_fields = [f.strip() for f in args.required_fields.split(',')]
    
    # Run pipeline
    run_pii_masking_pipeline(
        project_id=args.project_id,
        input_path=args.input_path,
        output_table=args.output_table,
        dlp_template=args.dlp_template,
        crypto_key=args.crypto_key,
        secret_key=args.secret_key,
        required_fields=required_fields,
        pipeline_args=pipeline_args
    )
