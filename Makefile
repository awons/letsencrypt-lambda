AWS_REGION ?= eu-west-1

.PHONY: run-local
run-local: ; $(info Execute lambda locally:)
	cat "${EVENT}" | docker run\
		--rm\
		-i\
		-e DOCKER_LAMBDA_USE_STDIN=1\
		-v $(shell pwd):/var/host\
		-v $(shell pwd)/src:/var/task\
		--env-file .env\
		letsencrypt-lambda:runtime\
		lambda_function.lambda_handler

.PHONY: build-runtime
build-runtime: ; $(info Build runtime:)
	docker build\
		--target runtime\
		--tag letsencrypt-lambda:runtime\
		--file Dockerfile\
		.

.PHONY: extract-layers
extract-layers: ; $(info Extract and publish layers for lambda:)
	img2lambda\
		-i letsencrypt-lambda:runtime\
		-t docker\
		-r ${AWS_REGION}\
		-n letsencrypt-lambda\
		-o ./output

.PHONY: package
package: ; $(info Package function for publishing:)
	sed -i 's/^- /      - /' output/layers.yaml
	sed -e "/LAYERS_PLACEHOLDER/r output/layers.yaml" -e "s///" deployment/template/template.yaml > deployment/template/template-final.yaml
	sam package --template-file deployment/template/template-final.yaml\
		--output-template-file deployment/template/packaged.yaml\
		--region ${AWS_REGION}\
		--s3-bucket ${LAMBDA_S3_BUCKET}

.PHONY: deploy
deploy: ; $(info Deploy packaged function:)
	sam deploy --template-file deployment/template/packaged.yaml\
		--capabilities CAPABILITY_IAM\
		--no-fail-on-empty-changeset\
		--region ${AWS_REGION}\
		--parameter-overrides $(shell cat deployment/template/.properties)\
		--stack-name ${STACK_NAME}

.PHONY: create-lambda-s3-bucket
create-lambda-s3-bucket: ; $(info Create S3 bucket for lambda:)
	aws cloudformation deploy\
		--template-file deployment/s3-bucket.yml \
		--stack-name ${STACK_NAME}\
		--parameter-overrides BucketName="${BUCKET_NAME}"\
		--no-fail-on-empty-changeset

.PHONY: create-scheduled-event
create-scheduled-event: ; $(info Create scheduled event:)
	aws cloudformation deploy\
		--template-file deployment/scheduled-event.yml \
		--stack-name ${STACK_NAME}\
		--parameter-overrides EventInput="${EVENT_INPUT}"\
		--no-fail-on-empty-changeset
