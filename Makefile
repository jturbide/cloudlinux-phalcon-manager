.PHONY: check syntax lint test whitespace

check: syntax lint test whitespace

syntax:
	bash -n bin/cl-phalcon lib/*.sh tests/*.bats examples/*.sh

lint:
	shellcheck -x bin/cl-phalcon
	shellcheck tests/*.bats examples/*.sh

test:
	bats tests

whitespace:
	git diff --check
