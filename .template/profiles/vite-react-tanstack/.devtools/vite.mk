# Managed by studiobimo/project-template (profile vite-react-tanstack); change it there.
# Include it from Makefile, after base.mk, and add the project's own targets (and their
# .PHONY) there. A hosting profile's .devtools/host/host.mk is included at the end, when
# there is one: it adds deploy targets, more tsc projects and its own checks, and may move
# BUNDLE_DIR, since a host's plugin can put the client build somewhere else.

PNPM := cd $(ROOT) && $(MISE) exec -- pnpm

# The bundle budget. Raise a number in the project's Makefile, in the same pull request as
# the change that needs it, so the growth is reviewed rather than discovered.
BUNDLE_DIR ?= dist
BUNDLE_CHUNK_KIB ?= 450
BUNDLE_TOTAL_KIB ?= 550

# The tsc -b projects: the root tsconfig.json, which references the app's and the configs'.
TSC_PROJECTS := .

# Prettier only formats the web sources. Markdown, YAML and JSON belong to the shared
# hooks, and many of those files are managed: formatting them here would be drift.
PRETTIER_FILES := '**/*.{js,mjs,cjs,jsx,ts,tsx,css,html}'

.PHONY: install dev build preview test typecheck eslint fmt fmt-check budget audit ci check lock clean

install: ## Install the packages pnpm-lock.yaml pins
	$(PNPM) install --frozen-lockfile

dev: ## Vite dev server
	$(PNPM) exec vite

# The router plugin regenerates src/routeTree.gen.ts on every build. If that changed the
# committed file, the route tree in git was stale: fail, so the new one gets committed.
build: ## Production build; fails if it had to rewrite a stale src/routeTree.gen.ts
	@cd $(ROOT) && before="$$(git hash-object src/routeTree.gen.ts 2>/dev/null || true)" \
		&& $(MISE) exec -- pnpm exec vite build \
		&& after="$$(git hash-object src/routeTree.gen.ts 2>/dev/null || true)" \
		&& if [ "$${before}" != "$${after}" ]; then \
			echo "✖ src/routeTree.gen.ts was stale and the build rewrote it: commit it" >&2; exit 1; \
		fi

preview: build ## Serve the production build locally
	$(PNPM) exec vite preview

test: ## Unit tests, once
	$(PNPM) exec vitest run

typecheck: ## Type-check every tsconfig project reference
	$(PNPM) exec tsc -b $(TSC_PROJECTS)

eslint: ## ESLint over the whole tree, warnings included
	$(PNPM) exec eslint --max-warnings=0 .

fmt: ## Format the web sources with Prettier
	$(PNPM) exec prettier --write --log-level=warn $(PRETTIER_FILES)

fmt-check: ## Fail on web sources Prettier would change
	$(PNPM) exec prettier --check --log-level=warn $(PRETTIER_FILES)

budget: ## Fail if a client chunk or the whole bundle outgrows its budget (after build)
	cd $(ROOT) && $(MISE) exec -- node .devtools/scripts/bundle-budget.mjs \
		--dir $(BUNDLE_DIR) --chunk-kib $(BUNDLE_CHUNK_KIB) --total-kib $(BUNDLE_TOTAL_KIB)

audit: ## Fail on high or critical advisories in the packages that ship
	$(PNPM) audit --prod --audit-level=high

# Build before typecheck: a route added without running the dev server only exists in
# the route tree once the build has written it.
ci: install build typecheck eslint fmt-check test budget audit ## What the CI workflow runs

check: lint ci ## Everything CI runs

lock: lock-tools ## Refresh every lockfile after a version change
	$(PNPM) install

clean: ## Remove build outputs
	cd $(ROOT) && rm -rf dist coverage node_modules/.tmp node_modules/.vite

-include $(ROOT)/.devtools/host/host.mk
