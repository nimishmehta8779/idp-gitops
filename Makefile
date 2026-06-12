.PHONY: backstage-dev backstage-stop backstage-restart

backstage-dev:
	$(MAKE) -C infrastructure backstage-dev

backstage-stop:
	$(MAKE) -C infrastructure backstage-stop

backstage-restart:
	$(MAKE) -C infrastructure backstage-restart

.PHONY: estimate-cost
estimate-cost:
	@./scripts/estimate-cost.sh t3.large 3

.PHONY: catalog-hygiene
catalog-hygiene:
	@./scripts/catalog-hygiene.sh

.PHONY: install-kyverno-policies
install-kyverno-policies:
	$(MAKE) -C infrastructure install-kyverno-policies

.PHONY: test-kyverno
test-kyverno:
	$(MAKE) -C infrastructure test-kyverno



