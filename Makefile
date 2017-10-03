REPO?=quay.io/beekhof/basic-operator
TAG?=$(shell git rev-parse --short HEAD)
NAMESPACE?=po-e2e-$(shell LC_CTYPE=C tr -dc a-z0-9 < /dev/urandom | head -c 13 ; echo '')
KUBECONFIG?=$(HOME)/.kube/config

PROMU := $(GOPATH)/bin/promu
PREFIX ?= $(shell pwd)

pkgs = $(shell go list ./... | grep -v /vendor/ | grep -v /test/)

all: check-license format build test

build: promu
	@$(PROMU) build --prefix $(PREFIX)

crossbuild: promu
	@$(PROMU) crossbuild

test:
	@go test -short $(pkgs)

format:
	go fmt $(pkgs)

container:
	docker build -t $(REPO):$(TAG) .

e2e-test:
	go test -timeout 20m -v ./test/e2e/ $(TEST_RUN_ARGS) --kubeconfig=$(KUBECONFIG) --operator-image=$(REPO):$(TAG) --namespace=$(NAMESPACE)

e2e-status:
	kubectl get basic,servicemonitor,statefulsets,deploy,svc,endpoints,pods,cm,secrets,replicationcontrollers --all-namespaces

e2e:
	$(MAKE) container
	$(MAKE) e2e-test

clean-e2e:
	kubectl -n $(NAMESPACE) delete basic,servicemonitor,statefulsets,deploy,svc,endpoints,pods,cm,secrets,replicationcontrollers --all
	kubectl delete namespace $(NAMESPACE)

promu:
	@go get -u github.com/prometheus/promu

embedmd:
	@go get github.com/campoy/embedmd

generate: jsonnet-docker
	docker run --rm -v `pwd`:/go/src/github.com/beekhof/basic-operator po-jsonnet make jsonnet generate-bundle docs

generate-bundle:
	hack/generate-bundle.sh

jsonnet-docker:
	docker build -f scripts/jenkins/jsonnet/Dockerfile -t po-jsonnet .

.PHONY: all build crossbuild test format check-license container e2e-test e2e-status e2e clean-e2e embedmd apidocgen docs
