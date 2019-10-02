from cert_manager import CertManager
from sentry_sdk.integrations.aws_lambda import AwsLambdaIntegration
import os
import sentry_sdk
import shutil

sentry_sdk.init(dsn=os.environ['SENTRY_DSN'],
                environment=os.environ['ENVIRONMENT'],
                integrations=[AwsLambdaIntegration()])


def lambda_handler(event, context):
    domains = event['domains'].split(",")
    email = event['email']
    acm_region = event['region']

    tmp_path = f'/tmp/{domains[0]}'
    if os.path.isdir(tmp_path):
        shutil.rmtree(tmp_path)
    os.makedirs(tmp_path)

    manager = CertManager(tmp_path, acm_region)
    result = manager.renew_or_create_cert(domains, email)

    if result is True:
        return f'Issued or renewd certificate for: {",".join(domains)}'
    else:
        return f'Nothing to do for: {",".join(domains)}'
