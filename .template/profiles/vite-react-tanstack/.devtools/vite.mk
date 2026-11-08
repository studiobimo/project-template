# Managed by studiobimo/project-template (profile vite-react-tanstack); change it there.
# Include it from Makefile, after base.mk, and add the project's own targets (and their
# .PHONY) there. A hosting profile's .devtools/host/host.mk is included at the end, when
# there is one: it adds deploy targets, more tsc projects and its own checks, and may move
# BUNDLE_DIR, since a host's plugin can put the client build somewhere else.

PNPM := cd $(ROOT) && $(MISE_EXEC) pnpm

# The app's directory, from the repository's root. A workspace sets APP_DIR in Makefile, above
# the line that includes this file, or lists every app in APPS when it has more than one. These
# expand when a recipe runs, so make and gen.mjs, which finds the line anywhere in Makefile,
# still agree if it ends up below.
#
# build, typecheck, budget, clean and a host's types and deploy run once per app in APP_LIST,
# each as <target>-app with APP_DIR set to that app. dev and preview take the first app.
# APP=<dir> narrows any of them to one app: make -C .devtools build APP=apps/site.
APPS ?=
APP_DIR ?= $(or $(APP),$(firstword $(APPS)),.)
APP_LIST = $(or $(APP),$(APPS),$(APP_DIR))
APP_CD = cd $(ROOT)/$(APP_DIR)
APP_PNPM = $(APP_CD) && $(MISE_EXEC) pnpm
each-app = @for app in $(APP_LIST); do $(MAKE) --no-print-directory APP_DIR="$${app}" $(1) || exit 1; done

# The bundle budget. Raise a number in the project's Makefile, in the same pull request as
# the change that needs it, so the growth is reviewed rather than discovered. One app can
# have its own: BUNDLE_DIR@apps/site := dist/worker, BUNDLE_TOTAL_KIB@apps/site := 200.
per-app = $(or $($(1)@$(APP_DIR)),$($(1)))
BUNDLE_DIR ?= dist
BUNDLE_CHUNK_KIB ?= 450
BUNDLE_TOTAL_KIB ?= 550

# The tsc -b projects of an app, from APP_DIR: its tsconfig.json references the app's and the
# configs', and a hosting profile adds its own. Every other workspace package is found by its
# src/ and checked on its own tsconfig.json.
TSC_PROJECTS := .

# The checks every workspace package gets, by what it has: scripts/packages.mjs runs in each
# one. They tell the apps from the other packages by ALL_APPS, which APP does not narrow.
PACKAGES = $(PNPM) --recursive exec node $(ROOT)/.devtools/scripts/packages.mjs
ALL_APPS = $(or $(APPS),$(APP_DIR))

# Prettier and ESLint run from the root, as the hooks do, so they cover a workspace's every
# package. Prettier only formats the web sources. Markdown, YAML and JSON belong to the shared
# hooks, and many of those files are managed: formatting them here would be drift.
PRETTIER_FILES := '**/*.{js,mjs,cjs,jsx,ts,tsx,css,html}'

# A hosting profile deploys to these environments, and each ships from one branch, so a laptop
# cannot put a feature branch on production. Its deploy target takes ENV=<one of them>; the
# recipe line stops it unless it was given one. A project that has no development environment
# or develop branch sets DEPLOY_ENVS := production in Makefile; the first one listed is the
# default of deploy.yml's manual run.
DEPLOY_ENVS ?= development production
DEPLOY_BRANCH_development := develop
DEPLOY_BRANCH_production := main
space := $(subst ,, )
deploy-env-pattern = $(subst $(space),|,$(strip $(DEPLOY_ENVS)))
require-deploy-env = @case "$(ENV)" in $(deploy-env-pattern)) ;; \
	*) echo "$(MSG_DEPLOY_USAGE)" >&2; exit 1 ;; esac

MSG_ROUTES_STALE := $(GLYPH_FAIL) src/routeTree.gen.ts was stale and the build rewrote it: commit it
MSG_DEPLOY_USAGE = $(GLYPH_FAIL) usage: $(DEVTOOLS) deploy ENV=$(deploy-env-pattern)

deploy-envs:
	@echo $(DEPLOY_ENVS)

# A checkout of a push is detached, so git names no branch there. A run from Actions has the
# branch it started on in GITHUB_REF_NAME, and one from Workers Builds in WORKERS_CI_BRANCH.
deploy-branch:
	$(require-deploy-env)
	@branch=$${GITHUB_REF_NAME:-$${WORKERS_CI_BRANCH:-$$(git branch --show-current)}}; \
	[ "$$branch" = "$(DEPLOY_BRANCH_$(ENV))" ] || { \
		echo "$(GLYPH_FAIL) $(ENV) ships from $(DEPLOY_BRANCH_$(ENV)), not $$branch" >&2; \
		exit 1; }

.PHONY: deploy-envs install dev build build-app preview test typecheck typecheck-app eslint knip fmt fmt-check budget budget-app audit playwright-install ci check lock clean clean-app deploy-branch

install: ## Install the packages pnpm-lock.yaml pins
	$(PNPM) install --frozen-lockfile

dev: ## Vite dev server
	$(APP_PNPM) exec vite

# The router plugin regenerates src/routeTree.gen.ts on every build. If that changed the
# committed file, the route tree in git was stale: fail, so the new one gets committed.
build: ## Production build of every app; fails if it had to rewrite a stale src/routeTree.gen.ts
	$(call each-app,build-app)

build-app:
	@$(APP_CD) && before="$$(git hash-object src/routeTree.gen.ts 2>/dev/null || true)" \
		&& $(MISE_EXEC) pnpm exec vite build \
		&& after="$$(git hash-object src/routeTree.gen.ts 2>/dev/null || true)" \
		&& if [ "$${before}" != "$${after}" ]; then \
			echo "$(MSG_ROUTES_STALE)" >&2; exit 1; \
		fi

preview: build-app ## Serve the production build locally
	$(APP_PNPM) exec vite preview

test: ## Unit tests, once, in every package with a src/
	$(PACKAGES) test

typecheck: ## Type-check every app's tsconfig project references, and every other package's tsconfig.json
	$(call each-app,typecheck-app)
	$(PACKAGES) typecheck $(ALL_APPS)

typecheck-app:
	$(APP_PNPM) exec tsc -b $(TSC_PROJECTS)

eslint: ## ESLint over the whole tree, warnings included
	$(PNPM) exec eslint --max-warnings=0 .

knip: ## Fail on unused files, exports and dependencies
	$(PNPM) exec knip

fmt: ## Format the web sources with Prettier
	$(PNPM) exec prettier --write --log-level=warn $(PRETTIER_FILES)

fmt-check: ## Fail on web sources Prettier would change
	$(PNPM) exec prettier --check --log-level=warn $(PRETTIER_FILES)

budget: ## Fail if a client chunk or the whole bundle of any app outgrows its budget (after build)
	$(PACKAGES) apps $(ALL_APPS)
	$(call each-app,budget-app)

budget-app:
	$(APP_CD) && $(MISE_EXEC) node $(ROOT)/.devtools/scripts/bundle-budget.mjs \
		--dir $(call per-app,BUNDLE_DIR) --chunk-kib $(call per-app,BUNDLE_CHUNK_KIB) \
		--total-kib $(call per-app,BUNDLE_TOTAL_KIB)

audit: ## Fail on high or critical advisories in the packages that ship
	$(PNPM) audit --prod --audit-level=high

# For a project that runs Playwright. GitHub's runners set CI, and lack the browser's system
# libraries. The tests run headless, so CI skips the full Chrome that `chromium` also downloads.
PLAYWRIGHT_BROWSER ?= chromium

playwright-install: ## Install the browser Playwright drives
	$(APP_PNPM) exec playwright install $(if $(CI),--with-deps --only-shell) $(PLAYWRIGHT_BROWSER)

# Build before typecheck: a route added without running the dev server only exists in
# the route tree once the build has written it.
ci: install build typecheck eslint knip duplication fmt-check test budget audit ## What the CI workflow runs

check: lint ci ## Everything CI runs

lock: lock-tools ## Refresh every lockfile after a version change
	$(PNPM) install

clean: ## Remove build outputs
	$(call each-app,clean-app)

clean-app:
	$(APP_CD) && rm -rf dist coverage node_modules/.tmp node_modules/.vite

-include $(ROOT)/.devtools/host/host.mk
