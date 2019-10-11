# file: Makefile

# Copyright 2018 Datawire. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License

CI_DEBUG_KAT_BRANCH=

SHELL = bash

# Welcome to the Ambassador Makefile...

.PHONY: \
    clean version setup-develop print-vars \
    docker-push docker-images
.SECONDARY:

GIT_DIRTY ?= $(if $(shell git status --porcelain),dirty)

# This is only "kinda" the git branch name:
#
#  - if checked out is the synthetic merge-commit for a PR, then use
#    the PR's branch name (even though the merge commit we have
#    checked out isn't part of the branch")
#  - if this is a CI run for a tag (not a branch or PR), then use the
#    tag name
#  - if none of the above, then use the actual git branch name
#
# read: https://graysonkoonce.com/getting-the-current-branch-name-during-a-pull-request-in-travis-ci/
GIT_BRANCH ?= $(or $(TRAVIS_PULL_REQUEST_BRANCH),$(TRAVIS_BRANCH),$(shell git rev-parse --abbrev-ref HEAD))

GIT_COMMIT ?= $(shell git rev-parse --short HEAD)

# This commands prints the tag of this commit or "undefined".
GIT_TAG ?= $(shell git name-rev --tags --name-only $(GIT_COMMIT))

GIT_BRANCH_SANITIZED := $(shell printf $(GIT_BRANCH) | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-zA-Z0-9]/-/g' -e 's/-\{2,\}/-/g')

# This gives the _previous_ tag, plus a git delta, like
# 0.36.0-436-g8b8c5d3
GIT_DESCRIPTION := $(shell git describe --tags $(GIT_COMMIT))

# IS_PRIVATE: empty=false, nonempty=true
# Default is true if any of the git remotes have the string "private" in any of their URLs.
_git_remote_urls := $(shell git remote | xargs -n1 git remote get-url --all)
IS_PRIVATE ?= $(findstring private,$(_git_remote_urls))

# RELEASE_VERSION is an X.Y.Z[-prerelease] (semver) string that we
# will upload/release the image as.  It does NOT include a leading 'v'
# (trimming the 'v' from the git tag is what the 'patsubst' is for).
# If this is an RC or EA, then it includes the '-rcN' or '-eaN'
# suffix.
#
# BUILD_VERSION is of the same format, but is the version number that
# we build into the image.  Because an image built as a "release
# candidate" will ideally get promoted to be the GA image, we trim off
# the '-rcN' suffix.
RELEASE_VERSION = $(patsubst v%,%,$(or $(TRAVIS_TAG),$(shell git describe --tags --always)))$(if $(GIT_DIRTY),-dirty)
BUILD_VERSION = $(shell echo '$(RELEASE_VERSION)' | sed 's/-rc[0-9]*$$//')

ifndef DOCKER_REGISTRY
$(error DOCKER_REGISTRY must be set. Use make DOCKER_REGISTRY=- for a purely local build.)
endif

AMBASSADOR_DOCKER_REPO ?= $(if $(filter-out -,$(DOCKER_REGISTRY)),$(DOCKER_REGISTRY)/)ambassador$(if $(IS_PRIVATE),-private)

ifneq ($(DOCKER_EXTERNAL_REGISTRY),)
AMBASSADOR_EXTERNAL_DOCKER_REPO ?= $(DOCKER_EXTERNAL_REGISTRY)/ambassador$(if $(IS_PRIVATE),-private)
else
AMBASSADOR_EXTERNAL_DOCKER_REPO ?= $(AMBASSADOR_DOCKER_REPO)
endif

DOCKER_OPTS =

# This is the branch from ambassador-docs to pull for "make pull-docs".
# Override if you need to.
PULL_BRANCH ?= master

AMBASSADOR_DOCKER_TAG ?= $(RELEASE_VERSION)
AMBASSADOR_DOCKER_IMAGE ?= $(AMBASSADOR_DOCKER_REPO):$(AMBASSADOR_DOCKER_TAG)
AMBASSADOR_EXTERNAL_DOCKER_IMAGE ?= $(AMBASSADOR_EXTERNAL_DOCKER_REPO):$(AMBASSADOR_DOCKER_TAG)

YES_I_AM_UPDATING_THE_BASE_IMAGES ?=
YES_I_AM_OK_WITH_COMPILING_ENVOY ?=

ENVOY_FILE ?= envoy-bin/envoy-static-stripped

# IF YOU MESS WITH ANY OF THESE VALUES, YOU MUST RUN `make docker-update-base`.
  ENVOY_REPO ?= $(if $(IS_PRIVATE),git@github.com:datawire/envoy-private.git,git://github.com/datawire/envoy.git)
  ENVOY_COMMIT ?= 6e6ae35f214b040f76666d86b30a6ad3ceb67046
  ENVOY_COMPILATION_MODE ?= dbg


  # Increment BASE_ENVOY_RELVER on changes to `Dockerfile.base-envoy`, or Envoy recipes
  BASE_ENVOY_RELVER   ?= 4
  # Increment BASE_RUNTIME_RELVER on changes to `Dockerfile.base-runtime`
  BASE_RUNTIME_RELVER ?= 1
  # Increment BASE_PY_RELVER on changes to `Dockerfile.base-py` or `python/requirements.txt`
  BASE_PY_RELVER      ?= 1

  BASE_DOCKER_REPO   ?= quay.io/datawire/ambassador-base$(if $(IS_PRIVATE),-private)
  BASE_IMAGE.envoy   ?= $(BASE_DOCKER_REPO):envoy-$(BASE_ENVOY_RELVER).$(ENVOY_COMMIT).$(ENVOY_COMPILATION_MODE)
  BASE_IMAGE.runtime ?= $(BASE_DOCKER_REPO):runtime-$(BASE_RUNTIME_RELVER)
  BASE_IMAGE.py      ?= $(BASE_DOCKER_REPO):py-$(BASE_RUNTIME_RELVER).$(BASE_PY_RELVER)
# END LIST OF VARIABLES REQUIRING `make docker-update-base`.

#### Test service Dockerfile stuff.
# The test services live in subdirectories of test-services. TEST_SERVICE_ROOTS
# is the list of these directories.

TEST_SERVICE_ROOTS = $(notdir $(wildcard test-services/*))

# TEST_SERVICE_IMAGES maps each TEST_SERVICE_ROOT to test-$root.docker, since
# those are the names of the individual targets. We also add the auth-tls
# target here, by hand -- it has a special rule since it's also built from the
# test-services/auth directory.
TEST_SERVICE_IMAGES = $(patsubst %,test-%.docker,$(TEST_SERVICE_ROOTS) auth-tls)

# Set default tag values...
docker.tag.release    = $(AMBASSADOR_DOCKER_TAG)
docker.tag.release-rc = $(AMBASSADOR_EXTERNAL_DOCKER_REPO):$(RELEASE_VERSION) $(AMBASSADOR_EXTERNAL_DOCKER_REPO):$(BUILD_VERSION)-latest-rc
docker.tag.release-ea = $(AMBASSADOR_EXTERNAL_DOCKER_REPO):$(RELEASE_VERSION)
docker.tag.local      = $(AMBASSADOR_DOCKER_TAG)
docker.tag.base       = $(BASE_IMAGE.$(patsubst base-%.docker,%,$<))

TEST_SERVICE_VERSION ?= 0.0.3

# ...then set overrides for the test services.
test-%.docker.tag.release: docker.tag.release = quay.io/datawire/test_services:$(notdir $*)-$(TEST_SERVICE_VERSION)

LOCAL_REPO = $(if $(filter-out -,$(DOCKER_REGISTRY)),$(DOCKER_REGISTRY)/test_services,test_services)
test-%.docker.tag.local: docker.tag.local = $(LOCAL_REPO):$(notdir $*)-$(GIT_DESCRIPTION)

# ...and define some TEST_SERVICE_*_TAGS.
TEST_SERVICE_LOCAL_TAGS = $(addsuffix .tag.local,$(TEST_SERVICE_IMAGES))
TEST_SERVICE_RELEASE_TAGS = $(addsuffix .tag.release,$(TEST_SERVICE_IMAGES))

ifneq ($(DOCKER_REGISTRY), -)
TEST_SERVICE_LOCAL_PUSHES = $(addsuffix .push.local,$(TEST_SERVICE_IMAGES))
TEST_SERVICE_RELEASE_PUSHES = $(addsuffix .push.release,$(TEST_SERVICE_IMAGES))
endif

#### end test service stuff

# Default to _NOT_ using Kubernaut. At Datawire, we can set this to true,
# but outside, it works much better to assume that user has set up something
# and not try to override it.
USE_KUBERNAUT ?= false

KUBERNAUT=venv/bin/kubernaut
KUBERNAUT_VERSION=2018.10.24-d46c1f1
KUBERNAUT_CLAIM=$(KUBERNAUT) claims create --name $(CLAIM_NAME) --cluster-group main
KUBERNAUT_DISCARD=$(KUBERNAUT) claims delete $(CLAIM_NAME)

KUBECTL_VERSION = 1.16.1

# Only override KUBECONFIG if we're using Kubernaut
ifeq ($(USE_KUBERNAUT), true)
KUBECONFIG ?= $(shell pwd)/cluster.yaml
endif

SCOUT_APP_KEY=

KAT_CLIENT_DOCKER_REPO ?= $(if $(filter-out -,$(DOCKER_REGISTRY)),$(DOCKER_REGISTRY)/)kat-client$(if $(IS_PRIVATE),-private)
KAT_SERVER_DOCKER_REPO ?= $(if $(filter-out -,$(DOCKER_REGISTRY)),$(DOCKER_REGISTRY)/)kat-backend$(if $(IS_PRIVATE),-private)

KAT_CLIENT_DOCKER_IMAGE ?= $(KAT_CLIENT_DOCKER_REPO):$(AMBASSADOR_DOCKER_TAG)
KAT_SERVER_DOCKER_IMAGE ?= $(KAT_SERVER_DOCKER_REPO):$(AMBASSADOR_DOCKER_TAG)

KAT_IMAGE_PULL_POLICY ?= Always

KAT_CLIENT ?= venv/bin/kat_client

# Where to place binaries when we compile them
WATT ?= watt
KUBESTATUS ?= kubestatus

# This should maybe be replaced with a lighterweight dependency if we
# don't currently depend on go
GOOS=$(shell go env GOOS)
GOARCH=$(shell go env GOARCH)

CLAIM_FILE=kubernaut-claim.txt
CLAIM_NAME=$(shell cat $(CLAIM_FILE))


# "make" by itself doesn't make the website. It takes too long and it doesn't
# belong in the inner dev loop.
all:
	$(MAKE) setup-develop
	$(MAKE) docker-push
	$(MAKE) test

include build-aux/prelude.mk
include build-aux/var.mk
include build-aux/docker.mk

# clean_docker_images could just be a fixed list of the images that we
# generate, but writing that fixed list would require a human to
# figure out what that complete list is.
clean_docker_images  = $(wildcard *.docker)
clean_docker_images += $(patsubst %.tag.release,%,$(wildcard *.docker.tag.release))
clean_docker_images += $(patsubst %.tag.local,%,$(wildcard *.docker.tag.local))
clean: clean-test envoy-build-container.txt.clean $(addsuffix .clean,$(clean_docker_images))
	rm -rf docs/_book docs/_site docs/package-lock.json
	rm -rf helm/*.tgz
	rm -rf app.json
	rm -rf venv/bin/ambassador
	rm -rf python/ambassador/VERSION.py*
	rm -f *.docker
	rm -rf python/build python/dist python/ambassador.egg-info python/__pycache__
	find . \( -name .coverage -o -name .cache -o -name __pycache__ \) -print0 | xargs -0 rm -rf
	find . \( -name *.log \) -print0 | xargs -0 rm -rf
	rm -rf log.txt
	find python/tests \
		\( -name '*.out' -o -name 'envoy.json' -o -name 'intermediate.json' \) -print0 \
		| xargs -0 rm -f
	rm -f build/kat/client/kat_client
	rm -f build/kat/server/kat-server
	rm -f tools/sandbox/http_auth/docker-compose.yml
	rm -f tools/sandbox/grpc_auth/docker-compose.yml
	rm -f tools/sandbox/grpc_web/docker-compose.yaml tools/sandbox/grpc_web/*_pb.js
	rm -rf pkg/api.envoy.tmp/
	rm -rf envoy-bin
	rm -f envoy-build-image.txt
	rm -f cmd/ambex/ambex
# Files made by older versions.  Remove the tail of this list when the
# commit making the change gets far enough in to the past.
#
# 2019-09-23
	rm -f kat-server-docker-image/kat-server
	rm -f kat-sandbox/grpc_auth/docker-compose.yml
	rm -f kat-sandbox/grpc_web/docker-compose.yaml
	rm -f kat-sandbox/grpc_web/*_pb.js
	rm -f kat-sandbox/http_auth/docker-compose.yml

clobber: clean kill-docker-registry
	-rm -f build/kat/client/teleproxy
	-$(if $(filter-out -,$(ENVOY_COMMIT)),rm -rf envoy envoy-src)
	-rm -rf docs/node_modules
	-rm -rf venv && echo && echo "Deleted venv, run 'deactivate' command if your virtualenv is activated" || true

generate: pkg/api/kat/echo.pb.go
generate: pkg/api/envoy
generate: api/envoy
generate-clean: clobber
	rm -rf api/envoy pkg/api
.PHONY: generate generate-clean

print-%:
	@printf "$($*)"

print-vars:
	@echo "AMBASSADOR_DOCKER_IMAGE          = $(AMBASSADOR_DOCKER_IMAGE)"
	@echo "AMBASSADOR_DOCKER_REPO           = $(AMBASSADOR_DOCKER_REPO)"
	@echo "AMBASSADOR_DOCKER_TAG            = $(AMBASSADOR_DOCKER_TAG)"
	@echo "AMBASSADOR_EXTERNAL_DOCKER_IMAGE = $(AMBASSADOR_EXTERNAL_DOCKER_IMAGE)"
	@echo "AMBASSADOR_EXTERNAL_DOCKER_REPO  = $(AMBASSADOR_EXTERNAL_DOCKER_REPO)"
	@echo "CI_DEBUG_KAT_BRANCH              = $(CI_DEBUG_KAT_BRANCH)"
	@echo "DOCKER_EPHEMERAL_REGISTRY        = $(DOCKER_EPHEMERAL_REGISTRY)"
	@echo "DOCKER_EXTERNAL_REGISTRY         = $(DOCKER_EXTERNAL_REGISTRY)"
	@echo "DOCKER_OPTS                      = $(DOCKER_OPTS)"
	@echo "DOCKER_REGISTRY                  = $(DOCKER_REGISTRY)"
	@echo "BASE_DOCKER_REPO                 = $(BASE_DOCKER_REPO)"
	@echo "GIT_BRANCH                       = $(GIT_BRANCH)"
	@echo "GIT_BRANCH_SANITIZED             = $(GIT_BRANCH_SANITIZED)"
	@echo "GIT_COMMIT                       = $(GIT_COMMIT)"
	@echo "GIT_DESCRIPTION                  = $(GIT_DESCRIPTION)"
	@echo "GIT_DIRTY                        = $(GIT_DIRTY)"
	@echo "GIT_TAG                          = $(GIT_TAG)"
	@echo "KAT_CLIENT_DOCKER_IMAGE          = $(KAT_CLIENT_DOCKER_IMAGE)"
	@echo "KAT_SERVER_DOCKER_IMAGE          = $(KAT_SERVER_DOCKER_IMAGE)"
	@echo "KUBECONFIG                       = $(KUBECONFIG)"
	@echo "USE_KUBERNAUT                    = $(USE_KUBERNAUT)"
	@echo "BUILD_VERSION                    = $(BUILD_VERSION)"
	@echo "RELEASE_VERSION                  = $(RELEASE_VERSION)"

export-vars:
	@echo "export AMBASSADOR_DOCKER_IMAGE='$(AMBASSADOR_DOCKER_IMAGE)'"
	@echo "export AMBASSADOR_DOCKER_REPO='$(AMBASSADOR_DOCKER_REPO)'"
	@echo "export AMBASSADOR_DOCKER_TAG='$(AMBASSADOR_DOCKER_TAG)'"
	@echo "export AMBASSADOR_EXTERNAL_DOCKER_IMAGE='$(AMBASSADOR_EXTERNAL_DOCKER_IMAGE)'"
	@echo "export AMBASSADOR_EXTERNAL_DOCKER_REPO='$(AMBASSADOR_EXTERNAL_DOCKER_REPO)'"
	@echo "export CI_DEBUG_KAT_BRANCH='$(CI_DEBUG_KAT_BRANCH)'"
	@echo "export DOCKER_EPHEMERAL_REGISTRY='$(DOCKER_EPHEMERAL_REGISTRY)'"
	@echo "export DOCKER_EXTERNAL_REGISTRY='$(DOCKER_EXTERNAL_REGISTRY)'"
	@echo "export DOCKER_OPTS='$(DOCKER_OPTS)'"
	@echo "export DOCKER_REGISTRY='$(DOCKER_REGISTRY)'"
	@echo "export BASE_DOCKER_REPO='$(BASE_DOCKER_REPO)'"
	@echo "export GIT_BRANCH='$(GIT_BRANCH)'"
	@echo "export GIT_BRANCH_SANITIZED='$(GIT_BRANCH_SANITIZED)'"
	@echo "export GIT_COMMIT='$(GIT_COMMIT)'"
	@echo "export GIT_DESCRIPTION='$(GIT_DESCRIPTION)'"
	@echo "export GIT_DIRTY='$(GIT_DIRTY)'"
	@echo "export GIT_TAG='$(GIT_TAG)'"
	@echo "export KAT_CLIENT_DOCKER_IMAGE='$(KAT_CLIENT_DOCKER_IMAGE)'"
	@echo "export KAT_SERVER_DOCKER_IMAGE='$(KAT_SERVER_DOCKER_IMAGE)'"
	@echo "export KUBECONFIG='$(KUBECONFIG)'"
	@echo "export USE_KUBERNAUT='$(USE_KUBERNAUT)'"
	@echo "export BUILD_VERSION='$(BUILD_VERSION)'"
	@echo "export RELEASE_VERSION='$(RELEASE_VERSION)'"

# All of this will likely fail horribly outside of CI, for the record.
docker-registry: $(KUBECONFIG)
ifneq ($(DOCKER_EPHEMERAL_REGISTRY),)
	@if [ "$(TRAVIS)" != "true" ]; then \
		echo "make docker-registry is only for CI" >&2 ;\
		exit 1 ;\
	fi
	@if [ -z "$(KUBECONFIG)" ]; then \
		echo "No KUBECONFIG" >&2 ;\
		exit 1 ;\
	fi
	@if [ ! -r .docker_port_forward ]; then \
		echo "Starting local Docker registry in Kubernetes" ;\
		kubectl apply -f releng/docker-registry.yaml ;\
		while [ -z "$$(kubectl get pods -n docker-registry -ojsonpath='{.items[0].status.containerStatuses[0].state.running}')" ]; do echo pod wait...; sleep 1; done ;\
		sh -c 'kubectl port-forward --namespace=docker-registry deployment/registry 31000:5000 > /tmp/port-forward-log & echo $$! > .docker_port_forward' ;\
	else \
		echo "Local Docker registry should be already running" ;\
	fi
	while ! curl -i http://localhost:31000/ 2>/dev/null; do echo curl wait...; sleep 1; done
endif

kill-docker-registry:
	@if [ -r .docker_port_forward ]; then \
		echo "Stopping local Docker registry" ;\
		kill $$(cat .docker_port_forward) ;\
		kubectl delete -f releng/docker-registry.yaml ;\
		rm -f .docker_port_forward ;\
	else \
		echo "Docker registry should not be running" ;\
	fi

envoy-src: FORCE
	@echo "Getting Envoy sources..."
	@if test -d envoy && ! test -d envoy-src; then PS4=; set -x; mv envoy envoy-src; fi
# Ensure that GIT_DIR and GIT_WORK_TREE are unset so that `git bisect`
# and friends work properly.
	@PS4=; set -ex; { \
	    unset GIT_DIR GIT_WORK_TREE; \
	    git init $@; \
	    cd $@; \
	    if git remote get-url origin &>/dev/null; then \
	        git remote set-url origin $(ENVOY_REPO); \
	    else \
	        git remote add origin $(ENVOY_REPO); \
	    fi; \
	    if [[ $(ENVOY_REPO) == http://github.com/* || $(ENVOY_REPO) == https://github.com/* || $(ENVOY_REPO) == git://github.com/* ]]; then \
	        git remote set-url --push origin git@github.com:$(word 3,$(subst /, ,$(ENVOY_REPO)))/$(patsubst %.git,%,$(word 4,$(subst /, ,$(ENVOY_REPO)))).git; \
	    fi; \
	    git fetch --tags origin; \
	    if [ $(ENVOY_COMMIT) != '-' ]; then \
	        git checkout $(ENVOY_COMMIT); \
	    elif ! git rev-parse HEAD >/dev/null 2>&1; then \
	        git checkout origin/master; \
	    fi; \
	}

envoy-build-image.txt: FORCE envoy-src $(WRITE_IFCHANGED)
	@PS4=; set -ex -o pipefail; { \
	    pushd envoy-src/ci; \
	    . envoy_build_sha.sh; \
	    popd; \
	    echo docker.io/envoyproxy/envoy-build-ubuntu:$$ENVOY_BUILD_SHA | $(WRITE_IFCHANGED) $@; \
	}

envoy-build-container.txt: envoy-build-image.txt FORCE
	@PS4=; set -ex; { \
	    if [ $@ -nt $< ] && docker exec $$(cat $@) true; then \
	        exit 0; \
	    fi; \
	    if [ -e $@ ]; then \
	        docker kill $$(cat $@) || true; \
	    fi; \
	    docker run --detach --name=envoy-build --rm --privileged --volume=envoy-build:/root:rw $$(cat $<) tail -f /dev/null > $@; \
	}

envoy-build-container.txt.clean: %.clean:
	@PS4=; set -ex; { \
	    if [ -e $* ]; then \
	        docker kill $$(cat $*) || true; \
	    fi; \
	}
.PHONY: envoy-build-container.txt.clean

# We do everything with rsync and a persistent build-container
# (instead of using a volume), because
#  1. Docker for Mac's osxfs is very slow, so volumes are bad for
#     macOS users.
#  2. Volumes mounts just straight-up don't work for people who use
#     Minikube's dockerd.
ENVOY_SYNC_HOST_TO_DOCKER = rsync -Pav --delete --blocking-io -e "docker exec -i" envoy-src/ $$(cat envoy-build-container.txt):/root/envoy
ENVOY_SYNC_DOCKER_TO_HOST = rsync -Pav --delete --blocking-io -e "docker exec -i" $$(cat envoy-build-container.txt):/root/envoy/ envoy-src/

ENVOY_BASH.cmd = bash -c 'PS4=; set -ex; $(ENVOY_SYNC_HOST_TO_DOCKER); trap '\''$(ENVOY_SYNC_DOCKER_TO_HOST)'\'' EXIT; '$(call quote.shell,$1)
ENVOY_BASH.deps = envoy-build-container.txt

envoy-bin:
	mkdir -p $@
envoy-bin/envoy-static: $(ENVOY_BASH.deps) FORCE | envoy-bin
	@PS4=; set -ex; { \
	    if docker run --rm --entrypoint=true $(BASE_IMAGE.envoy); then \
	        rsync -Pav --blocking-io -e 'docker run --rm -i' $$(docker image inspect $(BASE_IMAGE.envoy) --format='{{.Id}}' | sed 's/^sha256://'):/usr/local/bin/envoy $@; \
	    else \
	        if [ -z '$(YES_I_AM_UPDATING_THE_BASE_IMAGES)' ]; then \
	            { set +x; } &>/dev/null; \
	            echo 'error: failed to pull $(BASE_IMAGE.envoy), but $$YES_I_AM_UPDATING_THE_BASE_IMAGES is not set'; \
	            echo '       If you are trying to update the base images, then set that variable to a non-empty value.'; \
	            echo '       If you are not trying to update the base images, then check your network connection and Docker credentials.'; \
	            exit 1; \
	        fi; \
	        if [ -z '$(YES_I_AM_OK_WITH_COMPILING_ENVOY)' ]; then \
	            { set +x; } &>/dev/null; \
	            echo 'error: Envoy compilation triggered, but $$YES_I_AM_OK_WITH_COMPILING_ENVOY is not set'; \
	            exit 1; \
	        fi; \
	        $(call ENVOY_BASH.cmd, \
	            docker exec --workdir=/root/envoy $$(cat envoy-build-container.txt) bazel build --verbose_failures -c $(ENVOY_COMPILATION_MODE) //source/exe:envoy-static; \
	            rsync -Pav --blocking-io -e 'docker exec -i' $$(cat envoy-build-container.txt):/root/envoy/bazel-bin/source/exe/envoy-static $@; \
	        ); \
	    fi; \
	}
%-stripped: % envoy-build-container.txt
	@PS4=; set -ex; { \
	    rsync -Pav --blocking-io -e 'docker exec -i' $< $$(cat envoy-build-container.txt):/tmp/$(<F); \
	    docker exec $$(cat envoy-build-container.txt) strip /tmp/$(<F) -o /tmp/$(@F); \
	    rsync -Pav --blocking-io -e 'docker exec -i' $$(cat envoy-build-container.txt):/tmp/$(@F) $@; \
	}

check-envoy: $(ENVOY_BASH.deps)
	$(call ENVOY_BASH.cmd, \
	    docker exec --workdir=/root/envoy $$(cat envoy-build-container.txt) bazel test --verbose_failures -c dbg --test_env=ENVOY_IP_TEST_VERSIONS=v4only //test/...; \
	)
.PHONY: check-envoy

envoy-shell: $(ENVOY_BASH.deps)
	$(call ENVOY_BASH.cmd, \
	    docker exec -it $$(cat envoy-build-container.txt) || true; \
	)
.PHONY: envoy-shell

base-%.docker: Dockerfile.base-% $(var.)BASE_IMAGE.% $(WRITE_IFCHANGED)
	@if [ -n "$(AMBASSADOR_DEV)" ]; then echo "Do not run this from a dev shell" >&2; exit 1; fi
	@PS4=; set -ex; { \
	    if ! docker run --rm --entrypoint=true $(BASE_IMAGE.$*); then \
	        if [ -z '$(YES_I_AM_UPDATING_THE_BASE_IMAGES)' ]; then \
	            { set +x; } &>/dev/null; \
	            echo 'error: failed to pull $(BASE_IMAGE.$*), but $$YES_I_AM_UPDATING_THE_BASE_IMAGES is not set'; \
	            echo '       If you are trying to update the base images, then set that variable to a non-empty value.'; \
	            echo '       If you are not trying to update the base images, then check your network connection and Docker credentials.'; \
	            exit 1; \
	        fi; \
	        docker build $(DOCKER_OPTS) $($@.DOCKER_OPTS) -t $(BASE_IMAGE.$*) -f $< .; \
	    fi; \
	}
	docker image inspect $(BASE_IMAGE.$*) --format='{{.Id}}' | $(WRITE_IFCHANGED) $@

base-envoy.docker: envoy-build-image.txt envoy-bin/envoy-static
base-envoy.docker.DOCKER_OPTS = --build-arg=ENVOY_BUILD_IMAGE=$$(cat envoy-build-image.txt)

base-runtime.docker.DOCKER_OPTS =

base-py.docker: base-runtime.docker
base-py.docker.DOCKER_OPTS = --build-arg=BASE_RUNTIME_IMAGE=$$(cat base-runtime.docker)

test-%.docker: test-services/%/Dockerfile $(MOVE_IFCHANGED) FORCE
	docker build --quiet --iidfile=$@.tmp test-services/$*
	$(MOVE_IFCHANGED) $@.tmp $@

test-auth-tls.docker: test-services/auth/Dockerfile $(MOVE_IFCHANGED) FORCE
	docker build --quiet --build-arg TLS=--tls --iidfile=$@.tmp test-services/auth
	$(MOVE_IFCHANGED) $@.tmp $@

test-services: $(TEST_SERVICE_IMAGES) $(TEST_SERVICE_LOCAL_TAGS) $(TEST_SERVICE_LOCAL_PUSHES)
test-services-release: $(TEST_SERVICE_IMAGES) $(TEST_SERVICE_RELEASE_TAGS) $(TEST_SERVICE_RELEASE_PUSHES)
.PHONY: test-services test-services-release

# XXX: Why doesn't just test-%.docker.push: test-%.docker.push.local work??
#
# This three-element form of $(addsuffix ...) is kind of an implicit foreach. 
# We're generating a rule for each word in $(TEST_SERVICE_IMAGES).
TEST_SERVICE_PUSH_TARGETS = $(addsuffix .push,$(TEST_SERVICE_IMAGES))
$(TEST_SERVICE_PUSH_TARGETS): %.push: %.push.local
.PHONY: $(TEST_SERVICE_PUSH_TARGETS)

docker-base-images: $(addsuffix .docker.tag.base,base-envoy base-runtime base-py)

docker-push-base-images: $(addsuffix .docker.push.base,base-envoy base-runtime base-py)

docker-update-base:
	$(MAKE) docker-base-images pkg/api/envoy
	$(MAKE) docker-push-base-images

ambassador-docker-image: ambassador.docker
ambassador.docker: Dockerfile cmd/ambex/ambex $(WATT) $(KUBESTATUS) bin_linux_amd64/kubectl $(WRITE_IFCHANGED) python/ambassador/VERSION.py FORCE
	set -x; docker build $(DOCKER_OPTS) $($@.DOCKER_OPTS) -t $(AMBASSADOR_DOCKER_IMAGE) .
	@docker image inspect $(AMBASSADOR_DOCKER_IMAGE) --format='{{.Id}}' | $(WRITE_IFCHANGED) $@
ambassador.docker: base-runtime.docker base-py.docker
ambassador.docker.DOCKER_OPTS += --build-arg=BASE_RUNTIME_IMAGE=$$(cat base-runtime.docker)
ambassador.docker.DOCKER_OPTS += --build-arg=BASE_PY_IMAGE=$$(cat base-py.docker)
ambassador.docker: $(ENVOY_FILE) $(var.)ENVOY_FILE
ambassador.docker.DOCKER_OPTS += --build-arg=ENVOY_FILE=$(ENVOY_FILE)

kat-client-docker-image: kat-client.docker
.PHONY: kat-client-docker-image
kat-client.docker: build/kat/client/Dockerfile base-py.docker build/kat/client/teleproxy build/kat/client/kat_client $(WRITE_IFCHANGED) $(var.)KAT_CLIENT_DOCKER_IMAGE
	docker build --build-arg BASE_PY_IMAGE=$$(cat base-py.docker) $(DOCKER_OPTS) -t $(KAT_CLIENT_DOCKER_IMAGE) build/kat/client
	@docker image inspect $(KAT_CLIENT_DOCKER_IMAGE) --format='{{.Id}}' | $(WRITE_IFCHANGED) $@

# build/kat/client/teleproxy always uses the linux/amd64 architecture
build/kat/client/teleproxy: go.mod
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o $@ github.com/datawire/teleproxy/cmd/teleproxy

# build/kat/client/kat_client always uses the linux/amd64 architecture
build/kat/client/kat_client: go.mod $(wildcard ./cmd/kat-client/*) pkg/api/kat/echo.pb.go
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o $@ ./cmd/kat-client

kat-server-docker-image: kat-server.docker
.PHONY:  kat-server-docker-image
kat-server.docker: $(wildcard build/kat/server/*) build/kat/server/kat-server $(var.)KAT_SERVER_DOCKER_IMAGE
	docker build $(DOCKER_OPTS) -t $(KAT_SERVER_DOCKER_IMAGE) build/kat/server
	@docker image inspect $(KAT_SERVER_DOCKER_IMAGE) --format='{{.Id}}' | $(WRITE_IFCHANGED) $@

# build/kat/server/kat-server always uses the linux/amd64 architecture
build/kat/server/kat-server: go.mod $(wildcard cmd/kat-server/* cmd/kat-server/*/*) pkg/api/kat/echo.pb.go
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o $@ ./cmd/kat-server

docker-images: mypy ambassador-docker-image

docker-push: docker-images
ifeq ($(DOCKER_REGISTRY),-)
	@echo "No DOCKER_REGISTRY set"
else
	@echo 'PUSH $(AMBASSADOR_DOCKER_IMAGE)'
	@set -o pipefail; \
		docker push $(AMBASSADOR_DOCKER_IMAGE) | python releng/linify.py push.log
endif

docker-push-kat-client: kat-client-docker-image
	@echo 'PUSH $(KAT_CLIENT_DOCKER_IMAGE)'
	@set -o pipefail; \
		docker push $(KAT_CLIENT_DOCKER_IMAGE) | python releng/linify.py push.log

docker-push-kat-server: kat-server-docker-image
	@echo 'PUSH $(KAT_SERVER_DOCKER_IMAGE)'
	@set -o pipefail; \
		docker push $(KAT_SERVER_DOCKER_IMAGE) | python releng/linify.py push.log

docker-push-kat: docker-push-kat-client docker-push-kat-server

# TODO: validate version is conformant to some set of rules might be a good idea to add here
python/ambassador/VERSION.py: FORCE $(WRITE_IFCHANGED)
	$(call check_defined, BUILD_VERSION, BUILD_VERSION is not set)
	$(call check_defined, GIT_BRANCH, GIT_BRANCH is not set)
	$(call check_defined, GIT_COMMIT, GIT_COMMIT is not set)
	$(call check_defined, GIT_DESCRIPTION, GIT_DESCRIPTION is not set)
	@echo "Generating and templating version information -> $(BUILD_VERSION)"
	sed \
		-e 's!{{VERSION}}!$(BUILD_VERSION)!g' \
		-e 's!{{GITBRANCH}}!$(GIT_BRANCH)!g' \
		-e 's!{{GITDIRTY}}!$(GIT_DIRTY)!g' \
		-e 's!{{GITCOMMIT}}!$(GIT_COMMIT)!g' \
		-e 's!{{GITDESCRIPTION}}!$(GIT_DESCRIPTION)!g' \
		< VERSION-template.py | $(WRITE_IFCHANGED) $@

version: python/ambassador/VERSION.py

# This is for the docker image, so we don't use the current arch, we hardcode to linux/amd64
$(WATT): go.mod
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o $@ github.com/datawire/teleproxy/cmd/watt

# This is for the docker image, so we don't use the current arch, we hardcode to linux/amd64
cmd/ambex/ambex: $(wildcard cmd/ambex/*.go) go.mod
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o $@ ./cmd/ambex

# This is for the docker image, so we don't use the current arch, we hardcode to linux/amd64
$(KUBESTATUS): go.mod
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o $@ github.com/datawire/teleproxy/cmd/kubestatus

$(CLAIM_FILE):
	@if [ -z $${CI+x} ]; then \
		echo kat-$${USER} > $@; \
	else \
		echo kat-$${USER}-$(shell uuidgen) > $@; \
	fi

$(KUBERNAUT): $(var.)KUBERNAUT_VERSION $(var.)GOOS $(var.)GOARCH | venv/bin/activate
	curl -o $(KUBERNAUT) http://releases.datawire.io/kubernaut/$(KUBERNAUT_VERSION)/$(GOOS)/$(GOARCH)/kubernaut
	chmod +x $(KUBERNAUT)

bin_%/kubectl: $(var.)KUBECTL_VERSION
	mkdir -p $(@D)
	curl --fail -o $@ -L https://storage.googleapis.com/kubernetes-release/release/v$(KUBECTL_VERSION)/bin/$(GOOS)/$(GOARCH)/kubectl
	chmod 755 $@

$(KAT_CLIENT): go.mod $(wildcard cmd/kat-client/*) pkg/api/kat/echo.pb.go
	go build -o $@ ./cmd/kat-client

setup-develop: venv $(KAT_CLIENT) $(KUBERNAUT) $(WATT) $(KUBESTATUS) version

cluster.yaml: $(CLAIM_FILE) $(KUBERNAUT)
ifeq ($(USE_KUBERNAUT), true)
	$(KUBERNAUT_DISCARD)
	$(KUBERNAUT_CLAIM)
	cp ~/.kube/$(CLAIM_NAME).yaml cluster.yaml
else
ifneq ($(USE_KUBERNAUT),)
ifneq ($(USE_KUBERNAUT),false)
	@echo "USE_KUBERNAUT must be true, false, or unset" >&2
	false
endif
endif
endif
# Make is too dumb to understand equivalence between absolute and
# relative paths.
$(CURDIR)/cluster.yaml: cluster.yaml

setup-test: cluster.yaml
	rm -rf /tmp/k8s-*.yaml /tmp/kat-*.yaml

# "make shell" drops you into a dev shell, and tries to set variables, etc., as
# needed:
#
# If USE_KUBERNAUT is true, we'll set up for Kubernaut, otherwise we'll assume 
# that the current KUBECONFIG is good.
#
# XXX KLF HACK: The dev shell used to include setting
# 	AMBASSADOR_DEV=1 \
# but I've ripped that out, since moving the KAT client into the cluster makes it
# much complex for the AMBASSADOR_DEV stuff to work correctly. I'll open an
# issue to finish sorting this out, but right now I want to get our CI builds 
# into better shape without waiting for that.

shell: setup-develop
	env \
	AMBASSADOR_DOCKER_IMAGE="$(AMBASSADOR_DOCKER_IMAGE)" \
	BASE_IMAGE.envoy="$(BASE_IMAGE.envoy)" \
	BASE_IMAGE.runtime="$(BASE_IMAGE.runtime)" \
	BASE_IMAGE.py="$(BASE_IMAGE.py)" \
	MAKE_KUBECONFIG="$(KUBECONFIG)" \
	bash --init-file releng/init.sh -i

clean-test:
	rm -f cluster.yaml
	test -x $(KUBERNAUT) && $(KUBERNAUT_DISCARD) || true
	rm -f $(CLAIM_FILE)

test: setup-develop
	cd python && env \
	AMBASSADOR_DOCKER_IMAGE="$(AMBASSADOR_DOCKER_IMAGE)" \
	BASE_IMAGE.envoy="$(BASE_IMAGE.envoy)" \
	BASE_IMAGE.runtime="$(BASE_IMAGE.runtime)" \
	BASE_IMAGE.py="$(BASE_IMAGE.py)" \
	KUBECONFIG="$(KUBECONFIG)" \
	KAT_CLIENT_DOCKER_IMAGE="$(KAT_CLIENT_DOCKER_IMAGE)" \
	KAT_SERVER_DOCKER_IMAGE="$(KAT_SERVER_DOCKER_IMAGE)" \
	KAT_IMAGE_PULL_POLICY="$(KAT_IMAGE_PULL_POLICY)" \
	PATH="$(shell pwd)/venv/bin:$(PATH)" \
	bash ../releng/run-tests.sh

test-list: setup-develop
	cd python && PATH="$(shell pwd)/venv/bin":$(PATH) pytest --collect-only -q

update-aws:
ifeq ($(AWS_ACCESS_KEY_ID),)
	@echo 'AWS credentials not configured; not updating https://s3.amazonaws.com/datawire-static-files/ambassador/$(STABLE_TXT_KEY)'
	@echo 'AWS credentials not configured; not updating latest version in Scout'
else
	@if [ -n "$(STABLE_TXT_KEY)" ]; then \
        printf "$(RELEASE_VERSION)" > stable.txt; \
		echo "updating $(STABLE_TXT_KEY) with $$(cat stable.txt)"; \
        aws s3api put-object \
            --bucket datawire-static-files \
            --key ambassador/$(STABLE_TXT_KEY) \
            --body stable.txt; \
	fi
	@if [ -n "$(SCOUT_APP_KEY)" ]; then \
		printf '{"application":"ambassador","latest_version":"$(RELEASE_VERSION)","notices":[]}' > app.json; \
		echo "updating $(SCOUT_APP_KEY) with $$(cat app.json)"; \
        aws s3api put-object \
            --bucket scout-datawire-io \
            --key ambassador/$(SCOUT_APP_KEY) \
            --body app.json; \
	fi
endif

release-prep:
	bash releng/release-prep.sh

release:
	@if ! [[ '$(RELEASE_VERSION)' =~ ^[0-9]+\.[0-9]+\.[0-9]+$$ ]]; then \
		printf "'make release' can only be run for commit tagged with 'vX.Y.Z'!\n"; \
		exit 1; \
	fi
	docker pull $(AMBASSADOR_DOCKER_REPO):$(RELEASE_VERSION)-rc-latest
	docker tag $(AMBASSADOR_DOCKER_REPO):$(RELEASE_VERSION)-rc-latest $(AMBASSADOR_DOCKER_REPO):$(RELEASE_VERSION)
	docker push $(AMBASSADOR_DOCKER_REPO):$(RELEASE_VERSION)
	$(MAKE) SCOUT_APP_KEY=app.json STABLE_TXT_KEY=stable.txt update-aws

release-rc: ambassador.docker.push.release-rc
release-rc: SCOUT_APP_KEY = testapp.json
release-rc: STABLE_TXT_KEY = teststable.txt
release-rc: update-aws

release-ea: ambassador.docker.push.release-ea
release-ea: SCOUT_APP_KEY = earlyapp.json
release-ea: STABLE_TXT_KEY = earlystable.txt
release-ea: update-aws

# ------------------------------------------------------------------------------
# Go gRPC bindings (Envoy)
# ------------------------------------------------------------------------------

# The version numbers of `protoc` (in this Makefile),
# `protoc-gen-gogofast` (in go.mod), and `protoc-gen-validate` (in
# go.mod) are based on
# https://github.com/envoyproxy/go-control-plane/blob/0e75602d5e36e96eafbe053999c0569edec9fe07/Dockerfile.ci
# (since that commit most closely corresponds to our ENVOY_COMMIT).
# Additionally, the package names of those programs are mentioned in
# ./go/pin.go, so that `go mod tidy` won't make the go.mod file forget
# about them.

PROTOC_VERSION = 3.5.1
PROTOC_PLATFORM = $(patsubst darwin,osx,$(GOOS))-$(patsubst amd64,x86_64,$(patsubst 386,x86_32,$(GOARCH)))

venv/protoc-$(PROTOC_VERSION)-$(PROTOC_PLATFORM).zip: $(var.)PROTOC_VERSION | venv/bin/activate
	curl -o $@ --fail -L https://github.com/protocolbuffers/protobuf/releases/download/v$(PROTOC_VERSION)/$(@F)
venv/bin/protoc: venv/protoc-$(PROTOC_VERSION)-$(PROTOC_PLATFORM).zip
	bsdtar -xf $< -C venv bin/protoc

venv/bin/protoc-gen-gogofast: go.mod $(FLOCK) | venv/bin/activate
	$(FLOCK) go.mod go build -o $@ github.com/gogo/protobuf/protoc-gen-gogofast

venv/bin/protoc-gen-validate: go.mod $(FLOCK) | venv/bin/activate
	$(FLOCK) go.mod go build -o $@ github.com/envoyproxy/protoc-gen-validate

api/envoy: envoy-src
	rsync --recursive --delete --delete-excluded --prune-empty-dirs --include='*/' --include='*.proto' --exclude='*' $</api/envoy/ $@

# Search path for .proto files
gomoddir = $(shell $(FLOCK) go.mod go list $1/... >/dev/null 2>/dev/null; $(FLOCK) go.mod go list -m -f='{{.Dir}}' $1)
# This list is based on 'imports=()' in https://github.com/envoyproxy/go-control-plane/blob/0e75602d5e36e96eafbe053999c0569edec9fe07/build/generate_protos.sh
# (since that commit most closely corresponds to our ENVOY_COMMIT).
#
# However, we make the following edits:
#  - "github.com/gogo/protobuf/protobuf" instead of "github.com/gogo/protobuf" (we add an
#    extra "/protobuf" at the end).  I have no idea why.  I have no idea how the
#    go-control-plane version works without the extra "/protobuf" at the end; it looks to
#    me like they would need it too.  It makes no sense.
#  - Mess with the paths under "istio.io/gogo-genproto", since in 929161c and ee07f27 they
#    moved the .proto files all around.  The reason this affects us and not
#    go-control-plane is that our newer Envoy needs googleapis'
#    "google/api/expr/v1alpha1/", which was added in 32e3935 (.pb.go files) and ee07f27
#    (.proto files).
imports += $(CURDIR)/api
imports += $(call gomoddir,github.com/envoyproxy/protoc-gen-validate)
imports += $(call gomoddir,github.com/gogo/protobuf)/protobuf
imports += $(call gomoddir,istio.io/gogo-genproto)/common-protos
imports += $(call gomoddir,istio.io/gogo-genproto)/common-protos/github.com/prometheus/client_model
imports += $(call gomoddir,istio.io/gogo-genproto)/common-protos/github.com/census-instrumentation/opencensus-proto/src

# Map from .proto files to Go package names
# This list is based on 'mappings=()' in https://github.com/envoyproxy/go-control-plane/blob/0e75602d5e36e96eafbe053999c0569edec9fe07/build/generate_protos.sh
# (since that commit most closely corresponds to our ENVOY_COMMIT).
#
# However, we make the following edits:
#  - Add an entry for "google/api/expr/v1alpha1/syntax.proto", which didn't exist yet in
#    the version that go-control-plane uses (see the comment around "imports" above).
mappings += gogoproto/gogo.proto=github.com/gogo/protobuf/gogoproto
mappings += google/api/annotations.proto=istio.io/gogo-genproto/googleapis/google/api
mappings += google/api/expr/v1alpha1/syntax.proto=istio.io/gogo-genproto/googleapis/google/api/expr/v1alpha1
mappings += google/api/http.proto=istio.io/gogo-genproto/googleapis/google/api
mappings += google/protobuf/any.proto=github.com/gogo/protobuf/types
mappings += google/protobuf/duration.proto=github.com/gogo/protobuf/types
mappings += google/protobuf/empty.proto=github.com/gogo/protobuf/types
mappings += google/protobuf/struct.proto=github.com/gogo/protobuf/types
mappings += google/protobuf/timestamp.proto=github.com/gogo/protobuf/types
mappings += google/protobuf/wrappers.proto=github.com/gogo/protobuf/types
mappings += google/rpc/code.proto=istio.io/gogo-genproto/googleapis/google/rpc
mappings += google/rpc/error_details.proto=istio.io/gogo-genproto/googleapis/google/rpc
mappings += google/rpc/status.proto=istio.io/gogo-genproto/googleapis/google/rpc
mappings += metrics.proto=istio.io/gogo-genproto/prometheus
mappings += opencensus/proto/trace/v1/trace.proto=istio.io/gogo-genproto/opencensus/proto/trace/v1
mappings += opencensus/proto/trace/v1/trace_config.proto=istio.io/gogo-genproto/opencensus/proto/trace/v1
mappings += validate/validate.proto=github.com/envoyproxy/protoc-gen-validate/validate
mappings += $(shell find $(CURDIR)/api/envoy -type f -name '*.proto' | sed -E 's,^$(CURDIR)/api/((.*)/[^/]*),\1=github.com/datawire/ambassador/pkg/api/\2,')

joinlist=$(if $(word 2,$2),$(firstword $2)$1$(call joinlist,$1,$(wordlist 2,$(words $2),$2)),$2)
comma = ,

_imports = $(call lazyonce,_imports,$(imports))
_mappings = $(call lazyonce,_mappings,$(mappings))
pkg/api/envoy: api/envoy $(FLOCK) venv/bin/protoc venv/bin/protoc-gen-gogofast venv/bin/protoc-gen-validate $(var.)_imports $(var.)_mappings
	rm -rf $@ $(@D).envoy.tmp
	mkdir -p $(@D).envoy.tmp
# go-control-plane `make generate`
	@set -e; find $(CURDIR)/api/envoy -type f -name '*.proto' | sed 's,/[^/]*$$,,' | uniq | while read -r dir; do \
		echo "Generating $$dir"; \
		./venv/bin/protoc \
			$(addprefix --proto_path=,$(_imports))  \
			--plugin=$(CURDIR)/venv/bin/protoc-gen-gogofast --gogofast_out='$(call joinlist,$(comma),plugins=grpc $(addprefix M,$(_mappings))):$(@D).envoy.tmp' \
			--plugin=$(CURDIR)/venv/bin/protoc-gen-validate --validate_out='lang=gogo:$(@D).envoy.tmp' \
			"$$dir"/*.proto; \
	done
# go-control-plane `make generate-patch`
# https://github.com/envoyproxy/go-control-plane/issues/173
	find $(@D).envoy.tmp -name '*.validate.go' -exec sed -E -i.bak 's,"(envoy/.*)"$$,"github.com/datawire/ambassador/pkg/api/\1",' {} +
	find $(@D).envoy.tmp -name '*.bak' -delete
# move things in to place
	mkdir -p $(@D)
	mv $(@D).envoy.tmp/envoy $@
	rmdir $(@D).envoy.tmp

# ------------------------------------------------------------------------------
# gRPC bindings for KAT
# ------------------------------------------------------------------------------

GRPC_WEB_VERSION = 1.0.3
GRPC_WEB_PLATFORM = $(GOOS)-x86_64

venv/bin/protoc-gen-grpc-web: $(var.)GRPC_WEB_VERSION $(var.)GRPC_WEB_PLATFORM | venv/bin/activate
	curl -o $@ -L --fail https://github.com/grpc/grpc-web/releases/download/$(GRPC_WEB_VERSION)/protoc-gen-grpc-web-$(GRPC_WEB_VERSION)-$(GRPC_WEB_PLATFORM)
	chmod 755 $@

pkg/api/kat/echo.pb.go: api/kat/echo.proto venv/bin/protoc venv/bin/protoc-gen-gogofast
	mkdir -p $(@D)
	./venv/bin/protoc \
		--proto_path=$(CURDIR)/api/kat \
		--plugin=$(CURDIR)/venv/bin/protoc-gen-gogofast --gogofast_out=plugins=grpc:$(@D) \
		$(CURDIR)/$<

tools/sandbox/grpc_web/echo_grpc_web_pb.js: api/kat/echo.proto venv/bin/protoc venv/bin/protoc-gen-grpc-web
	./venv/bin/protoc \
		--proto_path=$(CURDIR)/api/kat \
		--plugin=$(CURDIR)/venv/bin/protoc-gen-grpc-web --grpc-web_out=import_style=commonjs,mode=grpcwebtext:$(@D) \
		$(CURDIR)/$<

tools/sandbox/grpc_web/echo_pb.js: api/kat/echo.proto venv/bin/protoc
	./venv/bin/protoc \
		--proto_path=$(CURDIR)/api/kat \
		--js_out=import_style=commonjs:$(@D) \
		$(CURDIR)/$<

# ------------------------------------------------------------------------------
# KAT docker-compose sandbox
# ------------------------------------------------------------------------------

tools/sandbox/http_auth/docker-compose.yml tools/sandbox/grpc_auth/docker-compose.yml tools/sandbox/grpc_web/docker-compose.yaml: %: %.in kat-server.docker $(var.)KAT_SERVER_DOCKER_IMAGE
	sed 's,@KAT_SERVER_DOCKER_IMAGE@,$(KAT_SERVER_DOCKER_IMAGE),g' < $< > $@

tools/sandbox.http-auth: ## In docker-compose: run Ambassador, an HTTP AuthService, an HTTP backend service, and a TracingService
tools/sandbox.http-auth: tools/sandbox/http_auth/docker-compose.yml
	@echo " ---> cleaning HTTP auth tools/sandbox"
	@cd tools/sandbox/http_auth && docker-compose stop && docker-compose rm -f
	@echo " ---> starting HTTP auth tools/sandbox"
	@cd tools/sandbox/http_auth && docker-compose up --force-recreate --abort-on-container-exit --build
.PHONY: tools/sandbox.http-auth

tools/sandbox.grpc-auth: ## In docker-compose: run Ambassador, a gRPC AuthService, an HTTP backend service, and a TracingService
tools/sandbox.grpc-auth: tools/sandbox/grpc_auth/docker-compose.yml
	@echo " ---> cleaning gRPC auth tools/sandbox"
	@cd tools/sandbox/grpc_auth && docker-compose stop && docker-compose rm -f
	@echo " ---> starting gRPC auth tools/sandbox"
	@cd tools/sandbox/grpc_auth && docker-compose up --force-recreate --abort-on-container-exit --build
.PHONY: tools/sandbox.grpc-auth

tools/sandbox.web: ## In docker-compose: run Ambassador with gRPC-web enabled, and a gRPC backend service
tools/sandbox.web: tools/sandbox/grpc_web/docker-compose.yaml
tools/sandbox.web: tools/sandbox/grpc_web/echo_grpc_web_pb.js tools/sandbox/grpc_web/echo_pb.js
	@echo " ---> cleaning gRPC web tools/sandbox"
	@cd tools/sandbox/grpc_web && npm install && npx webpack
	@cd tools/sandbox/grpc_web && docker-compose stop && docker-compose rm -f
	@echo " ---> starting gRPC web tools/sandbox"
	@cd tools/sandbox/grpc_web && docker-compose up --force-recreate --abort-on-container-exit --build
.PHONY: tools/sandbox.web

# ------------------------------------------------------------------------------
# Virtualenv
# ------------------------------------------------------------------------------

venv: version venv/bin/ambassador

venv/bin/ambassador: venv/bin/activate python/requirements.txt
	@releng/install-py.sh dev requirements python/requirements.txt
	@releng/install-py.sh dev install python/requirements.txt
	@releng/fix_kube_client

venv/bin/activate: dev-requirements.txt
	test -d venv || virtualenv venv --python python3
	@releng/install-py.sh dev requirements $^
	@releng/install-py.sh dev install $^
	touch venv/bin/activate
	@releng/fix_kube_client

mypy-server-stop: venv
	venv/bin/dmypy stop

mypy-server: venv
	@if ! venv/bin/dmypy status >/dev/null; then \
		venv/bin/dmypy start -- --use-fine-grained-cache --follow-imports=skip --ignore-missing-imports ;\
		echo "Started mypy server" ;\
	fi

mypy: mypy-server
	time venv/bin/dmypy check python

# ------------------------------------------------------------------------------
# Website
# ------------------------------------------------------------------------------

pull-docs:
	@PS4=; set -ex; { \
	    git fetch https://github.com/datawire/ambassador-docs $(PULL_BRANCH); \
	    docs_head=$$(git rev-parse FETCH_HEAD); \
	    git subtree merge --prefix=docs "$${docs_head}"; \
	    git subtree split --prefix=docs --rejoin --onto="$${docs_head}"; \
	}
push-docs:
	@PS4=; set -ex; { \
	    git fetch https://github.com/datawire/ambassador-docs master; \
	    docs_old=$$(git rev-parse FETCH_HEAD); \
	    docs_new=$$(git subtree split --prefix=docs --rejoin --onto="$${docs_old}"); \
	    git push $(if $(GH_TOKEN),https://d6e-automaton:${GH_TOKEN}@github.com/,git@github.com:)datawire/ambassador-docs.git "$${docs_new}:refs/heads/$(or $(PUSH_BRANCH),master)"; \
	}
.PHONY: pull-docs push-docs

# ------------------------------------------------------------------------------
# Function Definitions
# ------------------------------------------------------------------------------

# Check that given variables are set and all have non-empty values,
# die with an error otherwise.
#
# Params:
#   1. Variable name(s) to test.
#   2. (optional) Error message to print.
check_defined = $(strip $(foreach 1,$1, $(call __check_defined,$1,$(strip $(value 2)))))
__check_defined = $(if $(value $1),, $(error Undefined $1$(if $2, ($2))))
