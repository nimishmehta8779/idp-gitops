.PHONY: backstage-dev backstage-stop backstage-restart

backstage-dev:
	$(MAKE) -C infrastructure backstage-dev

backstage-stop:
	$(MAKE) -C infrastructure backstage-stop

backstage-restart:
	$(MAKE) -C infrastructure backstage-restart
