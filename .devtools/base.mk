# Managed by studiobimo/project-template; change it there. Project targets go in Makefile.

ROOT := $(abspath ..)
UV := uv --project $(CURDIR)
PRE_COMMIT := $(UV) run pre-commit
# python.org Python builds on macOS ship without a CA bundle until "Install
# Certificates" is run; hook installs download toolchains over HTTPS, so fall back
# to certifi's bundle unless one is already configured.
export SSL_CERT_FILE ?= $(shell $(UV) run --frozen python -c 'import certifi; print(certifi.where())' 2>/dev/null)

.DEFAULT_GOAL := help
.PHONY: help setup lint scan lock-tools sync drift

help: ## List targets
	@grep -hE '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

setup: ## Install pinned tools and git hooks (pre-commit, commit-msg, pre-push)
	$(UV) sync --frozen
	cd $(ROOT) && $(PRE_COMMIT) install --install-hooks \
		--hook-type pre-commit --hook-type commit-msg --hook-type pre-push

lint: ## Run every pre-commit hook on all files
	cd $(ROOT) && $(PRE_COMMIT) run --all-files

scan: ## Secret and workflow security scans
	cd $(ROOT) && $(PRE_COMMIT) run gitleaks --all-files
	cd $(ROOT) && $(PRE_COMMIT) run zizmor --all-files

lock-tools: ## Refresh uv.lock after changing a tool version in pyproject.toml
	$(UV) lock

sync: ## Pull the files studiobimo/project-template manages (REF=<tag> for a specific release)
	@$(CURDIR)/scripts/template-sync.sh $(if $(REF),--ref $(REF))

drift: ## Show where this repo differs from the template, without changing anything
	@$(CURDIR)/scripts/template-sync.sh --check $(if $(REF),--ref $(REF))
