# Copyright 2016 The Kubernetes Authors.
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
# limitations under the License.

.PHONY: cluster-up cluster-down cluster-sync cluster-clean

KUBEVIRT_PROVIDER?=k8s-1.20
HPP_IMAGE?=hostpath-provisioner
TAG?=latest
DOCKER_REPO?=kubevirt
ARTIFACTS_PATH?=_out
GOLANG_VER?=1.16.8

all: controller hostpath-provisioner

hostpath-provisioner:
	GOLANG_VER=${GOLANG_VER} ./hack/build-provisioner.sh

hostpath-provisioner-plugin:
	GOLANG_VER=${GOLANG_VER} ./hack/build-csi.sh

image: image-controller image-csi

push: push-controller push-csi

push-controller: hostpath-provisioner image
	docker push $(DOCKER_REPO)/$(HPP_IMAGE):$(TAG)

image-controller: hostpath-provisioner
	docker build -t $(DOCKER_REPO)/$(HPP_IMAGE):$(TAG) -f Dockerfile.controller .

image-csi: hostpath-provisioner-plugin
	docker build -t $(DOCKER_REPO)/$(HPP_IMAGE)-csi:$(TAG) -f Dockerfile.csi .

push-csi: hostpath-provisioner-plugin image-csi
	docker push $(DOCKER_REPO)/$(HPP_IMAGE)-csi:$(TAG)

clean:
	rm -rf _out

build: clean hostpath-provisioner hostpath-provisioner-csi

cluster-up:
	KUBEVIRT_PROVIDER=${KUBEVIRT_PROVIDER} ./cluster-up/up.sh

cluster-down: 
	KUBEVIRT_PROVIDER=${KUBEVIRT_PROVIDER} ./cluster-up/down.sh

cluster-sync: cluster-clean
	KUBEVIRT_PROVIDER=${KUBEVIRT_PROVIDER} ./cluster-sync/sync.sh

cluster-clean:
	KUBEVIRT_PROVIDER=${KUBEVIRT_PROVIDER} ./cluster-sync/clean.sh

test:
	GOLANG_VER=${GOLANG_VER} ./hack/run-unit-test.sh
	hack/language.sh

test-functional:
	KUBEVIRT_PROVIDER=${KUBEVIRT_PROVIDER} gotestsum --format short-verbose --junitfile ${ARTIFACTS_PATH}/junit.functest.xml -- ./tests/... -kubeurl="" -kubeconfig="../_ci-configs/$(KUBEVIRT_PROVIDER)/.kubeconfig"

test-sanity:
	DOCKER_REPO=${DOCKER_REPO} hack/sanity.sh
