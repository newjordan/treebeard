# Developer entry points. Runtime dependencies are Bash 4+ and GNU coreutils.
# shellcheck is required for `make lint` and is installed by CI.

.PHONY: test lint check checksums

SHELL := bash

test:
	bash tests/run-tests.sh

lint:
	shellcheck -x install.sh package/run.sh package/treebeard scripts/update-checksums.sh tests/run-tests.sh

check: lint test

checksums:
	bash scripts/update-checksums.sh
