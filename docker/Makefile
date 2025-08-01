SHELL=/bin/bash
ELASTIC_REGISTRY ?= docker.elastic.co

# Determine the version to build.
ELASTIC_VERSION ?= $(shell ../vendor/jruby/bin/jruby bin/elastic-version)

ifdef STAGING_BUILD_NUM
  VERSION_TAG := $(ELASTIC_VERSION)-$(STAGING_BUILD_NUM)
else
  VERSION_TAG := $(ELASTIC_VERSION)
endif

ifdef DOCKER_ARCHITECTURE
  ARCHITECTURE := $(DOCKER_ARCHITECTURE)
else
  ARCHITECTURE := $(shell uname -m)
  # For MacOS
  ifeq ($(ARCHITECTURE), arm64)
	ARCHITECTURE := aarch64
  endif
endif

IMAGE_FLAVORS ?= oss full wolfi observability-sre
DEFAULT_IMAGE_FLAVOR ?= full

IMAGE_TAG := $(ELASTIC_REGISTRY)/logstash/logstash
HTTPD ?= logstash-docker-artifact-server

all: build-from-local-artifacts build-from-local-oss-artifacts public-dockerfiles

# Build from artifacts on the local filesystem, using an http server (running
# in a container) to provide the artifacts to the Dockerfile.
build-from-local-full-artifacts: dockerfile
	docker run --rm -d --name=$(HTTPD) \
	           -p 8000:8000 --expose=8000 -v $(ARTIFACTS_DIR):/mnt \
	           python:3 bash -c 'cd /mnt && python3 -m http.server'
	timeout 120 bash -c 'until curl -s localhost:8000 > /dev/null; do sleep 1; done'
	docker build --progress=plain --network=host -t $(IMAGE_TAG)-full:$(VERSION_TAG) -f $(ARTIFACTS_DIR)/Dockerfile-full data/logstash || \
	  (docker kill $(HTTPD); false); \
	docker tag $(IMAGE_TAG)-full:$(VERSION_TAG) $(IMAGE_TAG):$(VERSION_TAG);
	docker kill $(HTTPD)

build-from-local-oss-artifacts: dockerfile
	docker run --rm -d --name=$(HTTPD) \
	           -p 8000:8000 --expose=8000 -v $(ARTIFACTS_DIR):/mnt \
	           python:3 bash -c 'cd /mnt && python3 -m http.server'
	timeout 120 bash -c 'until curl -s localhost:8000 > /dev/null; do sleep 1; done'
	docker build --progress=plain --network=host -t $(IMAGE_TAG)-oss:$(VERSION_TAG) -f $(ARTIFACTS_DIR)/Dockerfile-oss data/logstash || \
	  (docker kill $(HTTPD); false);
	-docker kill $(HTTPD)

build-from-local-wolfi-artifacts: dockerfile
	docker run --rm -d --name=$(HTTPD) \
	           -p 8000:8000 --expose=8000 -v $(ARTIFACTS_DIR):/mnt \
	           python:3 bash -c 'cd /mnt && python3 -m http.server'
	timeout 120 bash -c 'until curl -s localhost:8000 > /dev/null; do sleep 1; done'
	docker build --progress=plain --network=host -t $(IMAGE_TAG)-wolfi:$(VERSION_TAG) -f $(ARTIFACTS_DIR)/Dockerfile-wolfi data/logstash || \
	  (docker kill $(HTTPD); false);
	-docker kill $(HTTPD)

build-from-local-observability-sre-artifacts: dockerfile
	docker run --rm -d --name=$(HTTPD) \
	           -p 8000:8000 --expose=8000 -v $(ARTIFACTS_DIR):/mnt \
	           python:3 bash -c 'cd /mnt && python3 -m http.server'
	timeout 120 bash -c 'until curl -s localhost:8000 > /dev/null; do sleep 1; done'
	docker build --progress=plain --network=host -t $(IMAGE_TAG)-observability-sre:$(VERSION_TAG) -f $(ARTIFACTS_DIR)/Dockerfile-observability-sre data/logstash || \
	  (docker kill $(HTTPD); false);
	-docker kill $(HTTPD)

COPY_FILES := $(ARTIFACTS_DIR)/docker/config/pipelines.yml $(ARTIFACTS_DIR)/docker/config/logstash-oss.yml $(ARTIFACTS_DIR)/docker/config/logstash-full.yml
COPY_FILES += $(ARTIFACTS_DIR)/docker/config/log4j2.file.properties $(ARTIFACTS_DIR)/docker/config/log4j2.properties
COPY_FILES += $(ARTIFACTS_DIR)/docker/env2yaml/env2yaml.go $(ARTIFACTS_DIR)/docker/env2yaml/go.mod $(ARTIFACTS_DIR)/docker/env2yaml/go.sum
COPY_FILES += $(ARTIFACTS_DIR)/docker/pipeline/default.conf $(ARTIFACTS_DIR)/docker/bin/docker-entrypoint

$(ARTIFACTS_DIR)/docker/config/pipelines.yml: data/logstash/config/pipelines.yml
$(ARTIFACTS_DIR)/docker/config/logstash-oss.yml: data/logstash/config/logstash-oss.yml
$(ARTIFACTS_DIR)/docker/config/logstash-full.yml: data/logstash/config/logstash-full.yml
$(ARTIFACTS_DIR)/docker/config/log4j2.file.properties: data/logstash/config/log4j2.file.properties
$(ARTIFACTS_DIR)/docker/config/log4j2.properties: data/logstash/config/log4j2.properties
$(ARTIFACTS_DIR)/docker/pipeline/default.conf: data/logstash/pipeline/default.conf
$(ARTIFACTS_DIR)/docker/bin/docker-entrypoint: data/logstash/bin/docker-entrypoint
$(ARTIFACTS_DIR)/docker/env2yaml/env2yaml.go: data/logstash/env2yaml/env2yaml.go
$(ARTIFACTS_DIR)/docker/env2yaml/go.mod: data/logstash/env2yaml/go.mod
$(ARTIFACTS_DIR)/docker/env2yaml/go.sum: data/logstash/env2yaml/go.sum

$(ARTIFACTS_DIR)/docker/%:
	cp -f $< $@

docker_paths:
	mkdir -p $(ARTIFACTS_DIR)/docker/
	mkdir -p $(ARTIFACTS_DIR)/docker/bin
	mkdir -p $(ARTIFACTS_DIR)/docker/config
	mkdir -p $(ARTIFACTS_DIR)/docker/env2yaml
	mkdir -p $(ARTIFACTS_DIR)/docker/pipeline

COPY_IRONBANK_FILES := $(ARTIFACTS_DIR)/ironbank/scripts/config/pipelines.yml $(ARTIFACTS_DIR)/ironbank/scripts/config/logstash.yml
COPY_IRONBANK_FILES += $(ARTIFACTS_DIR)/ironbank/scripts/config/log4j2.file.properties $(ARTIFACTS_DIR)/ironbank/scripts/config/log4j2.properties
COPY_IRONBANK_FILES += $(ARTIFACTS_DIR)/ironbank/scripts/pipeline/default.conf $(ARTIFACTS_DIR)/ironbank/scripts/bin/docker-entrypoint $(ARTIFACTS_DIR)/ironbank/scripts/go/src/env2yaml/env2yaml.go
COPY_IRONBANK_FILES += $(ARTIFACTS_DIR)/ironbank/scripts/go/src/env2yaml/go.mod $(ARTIFACTS_DIR)/ironbank/scripts/go/src/env2yaml/go.sum $(ARTIFACTS_DIR)/ironbank/scripts/go/src/env2yaml/vendor/modules.txt $(ARTIFACTS_DIR)/ironbank/LICENSE $(ARTIFACTS_DIR)/ironbank/README.md

$(ARTIFACTS_DIR)/ironbank/scripts/config/pipelines.yml: data/logstash/config/pipelines.yml
$(ARTIFACTS_DIR)/ironbank/scripts/config/logstash.yml: data/logstash/config/logstash-full.yml
$(ARTIFACTS_DIR)/ironbank/scripts/config/log4j2.file.properties: data/logstash/config/log4j2.file.properties
$(ARTIFACTS_DIR)/ironbank/scripts/config/log4j2.properties: data/logstash/config/log4j2.properties
$(ARTIFACTS_DIR)/ironbank/scripts/pipeline/default.conf: data/logstash/pipeline/default.conf
$(ARTIFACTS_DIR)/ironbank/scripts/bin/docker-entrypoint: data/logstash/bin/docker-entrypoint
$(ARTIFACTS_DIR)/ironbank/scripts/go/src/env2yaml/env2yaml.go: data/logstash/env2yaml/env2yaml.go
$(ARTIFACTS_DIR)/ironbank/scripts/go/src/env2yaml/go.mod: ironbank/go/src/env2yaml/go.mod
$(ARTIFACTS_DIR)/ironbank/scripts/go/src/env2yaml/go.sum: ironbank/go/src/env2yaml/go.sum
$(ARTIFACTS_DIR)/ironbank/scripts/go/src/env2yaml/vendor/modules.txt: ironbank/go/src/env2yaml/vendor/modules.txt
$(ARTIFACTS_DIR)/ironbank/LICENSE: ironbank/LICENSE
$(ARTIFACTS_DIR)/ironbank/README.md: ironbank/README.md

$(ARTIFACTS_DIR)/ironbank/%:
	cp -f $< $@

ironbank_docker_paths:
	mkdir -p $(ARTIFACTS_DIR)/ironbank/
	mkdir -p $(ARTIFACTS_DIR)/ironbank/scripts
	mkdir -p $(ARTIFACTS_DIR)/ironbank/scripts/bin
	mkdir -p $(ARTIFACTS_DIR)/ironbank/scripts/config
	mkdir -p $(ARTIFACTS_DIR)/ironbank/scripts/go/src/env2yaml/vendor
	mkdir -p $(ARTIFACTS_DIR)/ironbank/scripts/pipeline

public-dockerfiles: public-dockerfiles_oss public-dockerfiles_full public-dockerfiles_wolfi public-dockerfiles_observability-sre public-dockerfiles_ironbank

public-dockerfiles_full: templates/Dockerfile.erb docker_paths $(COPY_FILES)
	../vendor/jruby/bin/jruby -S erb -T "-"\
		created_date="${BUILD_DATE}" \
		elastic_version="${ELASTIC_VERSION}" \
		arch="${ARCHITECTURE}" \
		version_tag="${VERSION_TAG}" \
		release="${RELEASE}" \
		image_flavor="full" \
		local_artifacts="false" \
		templates/Dockerfile.erb > "${ARTIFACTS_DIR}/Dockerfile-full" && \
	cd $(ARTIFACTS_DIR)/docker && \
	cp $(ARTIFACTS_DIR)/Dockerfile-full Dockerfile && \
	tar -zcf ../logstash-$(VERSION_TAG)-docker-build-context.tar.gz Dockerfile bin config env2yaml pipeline

build-from-dockerfiles_full: public-dockerfiles_full
	cd $(ARTIFACTS_DIR)/docker && \
	mkdir -p dockerfile_build_full && cd dockerfile_build_full && \
	tar -zxf ../../logstash-$(VERSION_TAG)-docker-build-context.tar.gz && \
	sed 's/artifacts/snapshots/g' Dockerfile > Dockerfile.tmp && mv Dockerfile.tmp Dockerfile && \
	docker build --progress=plain --network=host -t $(IMAGE_TAG)-dockerfile-full:$(VERSION_TAG) .

public-dockerfiles_oss: templates/Dockerfile.erb docker_paths $(COPY_FILES)
	../vendor/jruby/bin/jruby -S erb -T "-"\
		created_date="${BUILD_DATE}" \
		elastic_version="${ELASTIC_VERSION}" \
		arch="${ARCHITECTURE}" \
		version_tag="${VERSION_TAG}" \
		release="${RELEASE}" \
		image_flavor="oss" \
		local_artifacts="false" \
		templates/Dockerfile.erb > "${ARTIFACTS_DIR}/Dockerfile-oss" && \
	cd $(ARTIFACTS_DIR)/docker && \
	cp $(ARTIFACTS_DIR)/Dockerfile-oss Dockerfile && \
	tar -zcf ../logstash-oss-$(VERSION_TAG)-docker-build-context.tar.gz Dockerfile bin config env2yaml pipeline

build-from-dockerfiles_oss: public-dockerfiles_oss
	cd $(ARTIFACTS_DIR)/docker && \
	mkdir -p dockerfile_build_oss && cd dockerfile_build_oss && \
	tar -zxf ../../logstash-$(VERSION_TAG)-docker-build-context.tar.gz && \
	sed 's/artifacts/snapshots/g' Dockerfile > Dockerfile.tmp && mv Dockerfile.tmp Dockerfile && \
	docker build --progress=plain --network=host -t $(IMAGE_TAG)-dockerfile-oss:$(VERSION_TAG) .

public-dockerfiles_wolfi: templates/Dockerfile.erb docker_paths $(COPY_FILES)
	../vendor/jruby/bin/jruby -S erb -T "-"\
		created_date="${BUILD_DATE}" \
		elastic_version="${ELASTIC_VERSION}" \
		arch="${ARCHITECTURE}" \
		version_tag="${VERSION_TAG}" \
		release="${RELEASE}" \
		image_flavor="wolfi" \
		local_artifacts="false" \
		templates/Dockerfile.erb > "${ARTIFACTS_DIR}/Dockerfile-wolfi" && \
	cd $(ARTIFACTS_DIR)/docker && \
	cp $(ARTIFACTS_DIR)/Dockerfile-wolfi Dockerfile && \
	tar -zcf ../logstash-wolfi-$(VERSION_TAG)-docker-build-context.tar.gz Dockerfile bin config env2yaml pipeline

build-from-dockerfiles_wolfi: public-dockerfiles_wolfi
	cd $(ARTIFACTS_DIR)/docker && \
	mkdir -p dockerfile_build_wolfi && cd dockerfile_build_wolfi && \
	tar -zxf ../../logstash-$(VERSION_TAG)-docker-build-context.tar.gz && \
	sed 's/artifacts/snapshots/g' Dockerfile > Dockerfile.tmp && mv Dockerfile.tmp Dockerfile && \
	docker build --progress=plain --network=host -t $(IMAGE_TAG)-dockerfile-wolfi:$(VERSION_TAG) .

public-dockerfiles_observability-sre: templates/Dockerfile.erb docker_paths $(COPY_FILES)
	../vendor/jruby/bin/jruby -S erb -T "-"\
		created_date="${BUILD_DATE}" \
		elastic_version="${ELASTIC_VERSION}" \
		arch="${ARCHITECTURE}" \
		version_tag="${VERSION_TAG}" \
		release="${RELEASE}" \
		image_flavor="observability-sre" \
		local_artifacts="false" \
		templates/Dockerfile.erb > "${ARTIFACTS_DIR}/Dockerfile-observability-sre" && \
	cd $(ARTIFACTS_DIR)/docker && \
	cp $(ARTIFACTS_DIR)/Dockerfile-observability-sre Dockerfile && \
	tar -zcf ../logstash-observability-sre-$(VERSION_TAG)-docker-build-context.tar.gz Dockerfile bin config env2yaml pipeline

build-from-dockerfiles_observability-sre: public-dockerfiles_observability-sre
	cd $(ARTIFACTS_DIR)/docker && \
	mkdir -p dockerfile_build_observability-sre && cd dockerfile_build_observability-sre && \
	tar -zxf ../../logstash-observability-sre-$(VERSION_TAG)-docker-build-context.tar.gz && \
	sed 's/artifacts/snapshots/g' Dockerfile > Dockerfile.tmp && mv Dockerfile.tmp Dockerfile && \
	docker build --progress=plain --network=host -t $(IMAGE_TAG)-dockerfile-observability-sre:$(VERSION_TAG) .

public-dockerfiles_ironbank: templates/hardening_manifest.yaml.erb templates/IronbankDockerfile.erb ironbank_docker_paths $(COPY_IRONBANK_FILES)
	../vendor/jruby/bin/jruby -S erb -T "-"\
	  elastic_version="${ELASTIC_VERSION}" \
	  templates/hardening_manifest.yaml.erb > $(ARTIFACTS_DIR)/ironbank/hardening_manifest.yaml && \
	../vendor/jruby/bin/jruby -S erb -T "-"\
		created_date="${BUILD_DATE}" \
		elastic_version="${ELASTIC_VERSION}" \
		arch="${ARCHITECTURE}" \
		version_tag="${VERSION_TAG}" \
		release="${RELEASE}" \
		image_flavor="ironbank" \
		local_artifacts="false" \
		templates/IronbankDockerfile.erb > "${ARTIFACTS_DIR}/Dockerfile-ironbank" && \
	cd $(ARTIFACTS_DIR)/ironbank && \
	cp $(ARTIFACTS_DIR)/Dockerfile-ironbank Dockerfile && \
	tar -zcf ../logstash-ironbank-$(VERSION_TAG)-docker-build-context.tar.gz scripts Dockerfile hardening_manifest.yaml LICENSE README.md

# Generate the Dockerfiles from ERB templates.
dockerfile: templates/Dockerfile.erb
	$(foreach FLAVOR, $(IMAGE_FLAVORS), \
		../vendor/jruby/bin/jruby -S erb -T "-"\
			created_date="${BUILD_DATE}" \
			elastic_version="${ELASTIC_VERSION}" \
			arch="${ARCHITECTURE}" \
			version_tag="${VERSION_TAG}" \
			image_flavor="${FLAVOR}" \
			local_artifacts="${LOCAL_ARTIFACTS}" \
			templates/Dockerfile.erb > "${ARTIFACTS_DIR}/Dockerfile-${FLAVOR}" ; \
	)

clean:
	rm -f ${ARTIFACTS_DIR}/env2yaml/env2yaml-* ${ARTIFACTS_DIR}/Dockerfile


.PHONY: clean push
