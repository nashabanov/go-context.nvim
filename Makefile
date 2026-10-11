.PHONY: check test smoke fmt fmt-check

check: fmt-check test

test:
	sh tests/run.sh

smoke:
	sh tests/smoke.sh

fmt:
	stylua lua plugin tests

fmt-check:
	stylua --check lua plugin tests
