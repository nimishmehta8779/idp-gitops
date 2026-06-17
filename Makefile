ifneq (,$(wildcard .env))
    include .env
    export
endif

AWS_DEFAULT_REGION ?= us-east-1

.PHONY: backstage-dev backstage-stop backstage-restart

backstage-dev:
	$(MAKE) -C infrastructure backstage-dev

backstage-stop:
	$(MAKE) -C infrastructure backstage-stop

backstage-restart:
	$(MAKE) -C infrastructure backstage-restart

.PHONY: catalog-hygiene
catalog-hygiene:
	@./scripts/catalog-hygiene.sh

.PHONY: install-kyverno-policies
install-kyverno-policies:
	$(MAKE) -C infrastructure install-kyverno-policies

.PHONY: test-kyverno check-aws-resources estimate-cost emergency-cleanup watch-cleanup daily-cost-check install-safety pre-provision aws-creds
test-kyverno:
	$(MAKE) -C infrastructure test-kyverno

check-aws-resources:
	$(MAKE) -C infrastructure check-aws-resources

estimate-cost:
	$(MAKE) -C infrastructure estimate-cost

emergency-cleanup:
	$(MAKE) -C infrastructure emergency-cleanup

watch-cleanup:
	$(MAKE) -C infrastructure watch-cleanup

daily-cost-check:
	$(MAKE) -C infrastructure daily-cost-check

install-safety:
	$(MAKE) -C infrastructure install-safety

pre-provision:
	$(MAKE) -C infrastructure pre-provision

aws-creds:
	$(MAKE) -C infrastructure aws-creds

.PHONY: update-providerconfigs verify-aws
update-providerconfigs:
	$(MAKE) -C infrastructure update-providerconfigs

verify-aws:
	$(MAKE) -C infrastructure verify-aws

.PHONY: verify-network-infra provision-platform-network network-status
verify-network-infra:
	$(MAKE) -C infrastructure verify-network-infra

provision-platform-network:
	$(MAKE) -C infrastructure provision-platform-network

network-status:
	$(MAKE) -C infrastructure network-status

.PHONY: test-enterprise-flow
test-enterprise-flow:
	@./infrastructure/scripts/test-enterprise-flow.sh

.PHONY: caipe-up caipe-down caipe-logs caipe-token caipe-kubeconfig setup-caipe-argocd

setup-caipe-argocd:
	$(MAKE) -C infrastructure setup-caipe-argocd

caipe-token:
	$(MAKE) -C infrastructure caipe-token

caipe-kubeconfig:
	$(MAKE) -C infrastructure caipe-kubeconfig

caipe-up:
	$(MAKE) -C infrastructure caipe-up

caipe-down:
	$(MAKE) -C infrastructure caipe-down

caipe-logs:
	$(MAKE) -C infrastructure caipe-logs
