.PHONY: test test-feature

test:
	devcontainer features test --global-scenarios-only .

test-feature:
	devcontainer features test -f $(feature)
