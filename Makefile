.SILENT:
.PHONY: build push

IMAGE_TAG	= docker.io/jorgegv/dmarc-report
# the version number for this repo and the generated image
IMAGE_VERSION	= 1.2.7

# software versions to include
PARSER_VERSION	= 1.2.6
VIEWER_VERSION	= 1.2.4

default:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'


build:	## Build docker image
	docker build --no-cache \
		--build-arg PARSER_VERSION=$(PARSER_VERSION) \
		--build-arg VIEWER_VERSION=$(VIEWER_VERSION) \
		-t "$(IMAGE_TAG):$(IMAGE_VERSION)" \
		.
	docker image tag "$(IMAGE_TAG):$(IMAGE_VERSION)" "$(IMAGE_TAG):latest"


push:	## Push docker image to Docker hub
	docker image push "$(IMAGE_TAG):$(IMAGE_VERSION)"
	docker image push "$(IMAGE_TAG):latest"
