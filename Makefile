BIN_DIR=_output/bin
REL_OSARCH=linux/amd64
REPO_PATH=volcano.sh/volcano
IMAGE_PREFIX=volcanosh/vc
TAG=latest
RELEASE_VER=v0.1
GitSHA=`git rev-parse HEAD`
Date=`date "+%Y-%m-%d %H:%M:%S"`
LD_FLAGS=" \
    -X '${REPO_PATH}/pkg/version.GitSHA=${GitSHA}' \
    -X '${REPO_PATH}/pkg/version.Built=${Date}'   \
    -X '${REPO_PATH}/pkg/version.Version=${RELEASE_VER}'"

.EXPORT_ALL_VARIABLES:

all: vc-scheduler vc-controllers vc-admission vkctl

init:
	mkdir -p ${BIN_DIR}

vc-scheduler: init
	go build -ldflags ${LD_FLAGS} -o=${BIN_DIR}/vc-scheduler ./cmd/scheduler

vc-controllers: init
	go build -ldflags ${LD_FLAGS} -o=${BIN_DIR}/vc-controllers ./cmd/controllers

vc-admission: init
	go build -ldflags ${LD_FLAGS} -o=${BIN_DIR}/vc-admission ./cmd/admission

vkctl: init
	go build -ldflags ${LD_FLAGS} -o=${BIN_DIR}/vkctl ./cmd/cli

image_bins:
	go get github.com/mitchellh/gox
	CGO_ENABLED=0 gox -osarch=${REL_OSARCH} -ldflags ${LD_FLAGS} -output ${BIN_DIR}/${REL_OSARCH}/vkctl ./cmd/cli
	for name in controllers scheduler admission; do\
		CGO_ENABLED=0 gox -osarch=${REL_OSARCH} -ldflags ${LD_FLAGS} -output ${BIN_DIR}/${REL_OSARCH}/vc-$$name ./cmd/$$name; \
	done

images: image_bins
	for name in controllers scheduler admission; do\
		cp ${BIN_DIR}/${REL_OSARCH}/vc-$$name ./installer/dockerfile/$$name/; \
		docker build --no-cache -t $(IMAGE_PREFIX)-$$name:$(TAG) ./installer/dockerfile/$$name; \
		rm installer/dockerfile/$$name/vc-$$name; \
	done

admission-base-image:
	docker build --no-cache -t $(IMAGE_PREFIX)-admission-base:$(TAG) ./installer/dockerfile/admission/ -f ./installer/dockerfile/admission/Dockerfile.base;

generate-code:
	./hack/update-gencode.sh

unit-test:
	go list ./... | grep -v e2e | xargs go test -v -cover -covermode atomic -coverprofile coverage.txt

e2e-test-kind:
	./hack/run-e2e-kind.sh

clean:
	rm -rf _output/
	rm -f *.log

verify: generate-code
	hack/verify-gofmt.sh
	hack/verify-golint.sh
	hack/verify-gencode.sh
