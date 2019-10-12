import boto3
import certbot.main
import datetime
import os


class CertManager:
    def __init__(self, tmp_path, aws_region):
        self._acm_client = boto3.client('acm', region_name=aws_region)
        self._config_dir = f'{tmp_path}/config-dir'
        self._work_dir = f'{tmp_path}/work-dir'
        self._logs_dir = f'{tmp_path}/logs-dir'

    def renew_or_create_cert(self, domains, email):
        cert = self._find_cert(domains)
        if (cert and self._should_renew(cert)) or cert is None:
            self._issue_cert(domains, cert, email)
            return True
        else:
            return False

    def _find_cert(self, domains):
        paginator = self._acm_client.get_paginator('list_certificates')
        iterator = paginator.paginate(PaginationConfig={'MaxItems': 1000})
        for page in iterator:
            for cert in page['CertificateSummaryList']:
                cert = self._acm_client.describe_certificate(
                    CertificateArn=cert['CertificateArn'])
                sans = frozenset(cert['Certificate']
                                 ['SubjectAlternativeNames'])
                if sans.issubset(domains):
                    return cert

        return None

    def _should_renew(self, cert):
        now = datetime.datetime.now(datetime.timezone.utc)
        not_after = cert['Certificate']['NotAfter']
        return (not_after - now).days <= 30

    def _issue_cert(self, domains, cert, email):
        certbot.main.main([
            'certonly',
            '-n',
            '--agree-tos',
            # '--test-cert',
            '--email', email,
            '--dns-route53',
            '-d', ",".join(domains),
            '--config-dir', self._config_dir,
            '--work-dir', self._work_dir,
            '--logs-dir', self._logs_dir,
        ])

        path = f'{self._config_dir}/live/{domains[0]}/'

        certificate = self._read_file(path + 'cert.pem')
        private_key = self._read_file(path + 'privkey.pem')
        certificate_chain = self._read_file(path + 'chain.pem')

        self._store_cert(cert, certificate,
                         private_key, certificate_chain)

    def _store_cert(self, current_cert, certificate,
                    private_key, certificate_chain):
        certificate_arn = None
        if current_cert is not None:
            certificate_arn = current_cert['Certificate']['CertificateArn']

        if certificate_arn is None:
            self._acm_client.import_certificate(
                Certificate=certificate,
                PrivateKey=private_key,
                CertificateChain=certificate_chain
            )
        else:
            self._acm_client.import_certificate(
                CertificateArn=certificate_arn,
                Certificate=certificate,
                PrivateKey=private_key,
                CertificateChain=certificate_chain
            )

    def _read_file(self, path):
        with open(path, 'r') as file:
            return file.read()
