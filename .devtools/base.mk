# Managed by studiobimo/project-template; change it there. Project targets go in Makefile.

ROOT := $(abspath ..)
MISE := mise
LEFTHOOK := $(MISE) exec -- lefthook

.DEFAULT_GOAL := help
.PHONY: help setup lint scan lock-tools sync drift github

help: ## List targets
	@grep -hE '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

setup: ## Install the tools mise.toml pins and the git hooks (pre-commit, commit-msg, pre-push)
	cd $(ROOT) && $(MISE) trust --quiet mise.toml && $(MISE) install --locked
	cd $(ROOT) && $(LEFTHOOK) install

lint: ## Run the pre-commit hook on all files
	cd $(ROOT) && $(LEFTHOOK) run pre-commit --all-files

scan: ## Secret scan of the whole history, and the workflow security audit
	cd $(ROOT) && $(MISE) exec -- gitleaks git --redact
	cd $(ROOT) && $(MISE) exec -- zizmor --no-progress .github

lock-tools: ## Refresh mise.lock after changing a tool version in mise.toml
	cd $(ROOT) && $(MISE) lock

# A sync can bring newer tool versions, and mise.lock has to follow mise.toml.
sync: ## Pull the files studiobimo/project-template manages (REF=<tag> for a specific release)
	@$(CURDIR)/scripts/template-sync.sh $(if $(REF),--ref $(REF))
	@cd $(ROOT) && { git diff --quiet -- mise.toml || $(MISE) lock; }

drift: ## Show where this repo differs from the template, without changing anything
	@$(CURDIR)/scripts/template-sync.sh --check $(if $(REF),--ref $(REF))

github: ## Apply the org's GitHub settings and rulesets to this repo (CHECK=1 only compares; DESC=, ENVS=)
	@DESC="$(DESC)" ENVS="$(ENVS)" $(CURDIR)/scripts/github-setup.sh $(if $(CHECK),--check) $(if $(REF),--ref $(REF))
