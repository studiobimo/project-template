include base.mk

.PHONY: check lock clean

check: lint ## Everything CI runs

lock: lock-tools ## Refresh every lockfile after a version change

clean: ## Remove build outputs
	@echo "Nothing to clean yet."

# >>> template:init
.PHONY: init test
check: test
test: ## Test the sync and init scripts (template only)
	@$(ROOT)/.template/test.sh
init: ## Once, in a new project: make -C .devtools init NAME="My Project" SLUG=my-project DESC="What it is."
	@NAME="$(NAME)" SLUG="$(SLUG)" DESC="$(DESC)" ENVS="$(ENVS)" $(CURDIR)/scripts/init.sh
# <<< template:init
