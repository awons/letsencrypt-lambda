# Set of AWS CloudFormation templates for automation of LetsEncrypt certificates renewal

## Requirements

* Docker
* make
* AWS CLI (https://docs.aws.amazon.com/en_pv/cli/latest/userguide/cli-chap-install.html)
* SAM (https://docs.aws.amazon.com/en_pv/serverless-application-model/latest/developerguide/serverless-sam-cli-install.html)
* img2lambda (https://github.com/awslabs/aws-lambda-container-image-converter)
* Route53 has a hosted zone for domain you want to issue/renew certificate for
* Free account on Sentry to store exceptions (https://sentry.io)

Copy configuration files and fill them with your own data. Copied fiels are in `.gitignore`.

```bash
cp .env.dist .env
cp deployment/template/.properties.dist deployment/template/.properties
```
## Step by step instructions

Please replace any provided value with appropriate to your situation.

### 1. Create S3 bucket

This is the bucket where lambda function will be stored.

```bash
make create-lambda-s3-bucket STACK_NAME=your-stack-name BUCKET_NAME=your-backet-name
```

### 2. Create and deploy layers for function

Select region in which you want to store your layers.

```bash
make build-runtime
make extract-layers AWS_REGION=eu-west-1
```

### 3. Package function code

Region is required by SAM but not used by the template.

```bash 
make package AWS_REGION=eu-west-1 LAMBDA_S3_BUCKET=your-backet-name
```

### 4. Deploy function

Choose region this function should be deploy to and pick you CF stack name for it.

```bash
make deploy STACK_NAME=my-lambda-stack-name AWS_REGION=eu-west-1
```

### 5. Schedule issuing/renewal of your domain's certificate

This CF template will create a stack that will trigger lambda function and renew certificate. `domains` is a comma-separated list of domains for which one certificate should be issued/renewed.

```bash
make create-scheduled-event STACK_NAME=my-event-stack-name EVENT_INPUT='{\"domains\": \"example.com\", \"region\": \"us-east-1\", \"email\": \"your-email@example.com\"}'
```

## Run locally

```bash
make run-local EVENT=./test-events/event.json
```
