all:
	@echo "Usage: `make test` or `make test-force`"
test:
	cd test/ && python test-run.py
test-force:
	cd test/ && python test-run.py --force

.PHONY: test test-force
