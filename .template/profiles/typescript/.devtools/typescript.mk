# Managed by studiobimo/project-template (profile typescript); change it there.
# Include it from Makefile, after base.mk, and add the project's own targets (and their
# .PHONY) there.

PNPM := cd $(ROOT) && $(MISE_EXEC) pnpm
TURBO := $(PNPM) exec turbo
TS_DIR := $(ROOT)/.devtools/typescript

# Turborepo runs build, typecheck and test in dependency order, caches each package's result and,
# with AFFECTED_BASE set (CI narrowing a pull request: origin/<base>), runs the tests only of the
# packages that changed and of what depends on them. A laptop sets nothing, so it runs them all.
# CI_FULL=false is CI saying it narrowed.
ifneq ($(strip $(AFFECTED_BASE)),)
export TURBO_SCM_BASE := $(AFFECTED_BASE)
TURBO_AFFECTED := --affected
endif

# End-to-end and other suites that a narrowed run cannot say a change cannot break. `ci` runs them
# only when CI_FULL is not false. A project appends its own, in Makefile after the include:
# FULL_CI_TARGETS += e2e
FULL_CI_TARGETS ?=
MSG_FULL_CI_SKIPPED = $(GLYPH_OK) narrowed run (CI_FULL=false): skipped $(strip $(FULL_CI_TARGETS))
run-full-ci-targets = $(if $(strip $(FULL_CI_TARGETS)),$(if $(filter false,$(CI_FULL)),@echo "$(MSG_FULL_CI_SKIPPED)",@$(MAKE) --no-print-directory $(FULL_CI_TARGETS)),@:)

CACHE_DIR := node_modules/.cache

MSG_NODE_MISMATCH = $(GLYPH_FAIL) the Dockerfile copies Node $${have:-(no FROM node:<version>-…)}, \
	but mise.toml pins $${want}: change them together
MSG_PNPM_MISMATCH = $(GLYPH_FAIL) package.json pins pnpm $${have}, \
	but mise.toml pins $(call pinned-version,pnpm): change them together
MSG_IMAGE_USAGE =$(GLYPH_FAIL) usage: $(DEVTOOLS) image SERVICE=services/<name>

.PHONY: install build typecheck test eslint knip audit image node-image-check pnpm-pin-check ci check lock clean

install: ## Install the packages pnpm-lock.yaml pins
	$(PNPM) install --frozen-lockfile

build: ## Build every package, dependencies first (Turborepo caches the result)
	$(TURBO) run build

typecheck: ## Type-check every package against the built packages it depends on
	$(TURBO) run typecheck

test: ## Unit tests once in every package; only the affected ones when AFFECTED_BASE is set
	$(TURBO) run test $(TURBO_AFFECTED)

eslint: ## ESLint over the whole tree, warnings included
	$(PNPM) exec eslint --cache --cache-strategy content --cache-location $(CACHE_DIR)/eslint/ --max-warnings=0 .

knip: ## Fail on unused files, exports and dependencies
	$(PNPM) exec knip

audit: ## Fail on high or critical advisories in the packages that ship
	$(PNPM) audit --prod --audit-level=high

image: ## Build a service's image from the shared Dockerfile: make image SERVICE=services/<name>
	@test -n "$(SERVICE)" || { echo "$(MSG_IMAGE_USAGE)" >&2; exit 1; }
	docker build --platform linux/amd64 -f $(TS_DIR)/Dockerfile --build-arg SERVICE=$(SERVICE) \
		--build-arg PNPM_VERSION=$(call pinned-version,pnpm) -t $(notdir $(SERVICE)) $(ROOT)

node-image-check: ## Fail when the Dockerfile's Node is not the one mise.toml pins
	@want="$$(cd $(ROOT) && $(MISE_EXEC) node -p process.versions.node)"; \
		have="$$(sed -n 's/^FROM node:\([0-9][0-9.]*\)-.*/\1/p' $(TS_DIR)/Dockerfile)"; \
		[ "$${have}" = "$${want}" ] || { echo "$(MSG_NODE_MISMATCH)" >&2; exit 1; }

# Turborepo cannot find the workspace without a package manager in package.json. gen.mjs writes
# it from mise.toml's pin, so this is the one place a second copy of the version lives.
pnpm-pin-check: ## Fail when package.json's pnpm is not the one mise.toml pins
	@have="$$(cd $(ROOT) && $(MISE_EXEC) node -p 'require("./package.json").devEngines.packageManager.version')"; \
		[ "$${have}" = "$(call pinned-version,pnpm)" ] || { echo "$(MSG_PNPM_MISMATCH)" >&2; exit 1; }

# Build before typecheck and tests: a package's types and exports are its built output.
ci: install build typecheck eslint knip duplication test audit node-image-check pnpm-pin-check ## What the CI workflow runs; the FULL_CI_TARGETS too unless CI_FULL=false
	$(run-full-ci-targets)

check: lint ci ## Everything CI runs

lock: lock-tools ## Refresh every lockfile after a version change
	$(PNPM) install

clean: ## Remove build outputs and Turborepo's cache
	$(PNPM) --recursive exec rm -rf dist coverage
	cd $(ROOT) && rm -rf .turbo $(CACHE_DIR)
