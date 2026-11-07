# Managed by studiobimo/project-template (profile cloudflare); change it there.
# vite.mk includes it. Cloudflare's own targets, and its part of the shared ones.

WRANGLER = $(APP_PNPM) exec wrangler

# The plugin builds the client into dist/client and the Worker beside it. Only the client
# is downloaded by browsers, so only it has a budget.
BUNDLE_DIR := dist/client
TSC_PROJECTS += worker

.PHONY: types types-app deploy deploy-app

# The Env type is generated, not committed. Secret names come from .dev.vars.example, so CI,
# which has no .dev.vars, types the same Env as a laptop does.
types: ## Generate each Worker's Env type, worker/worker-configuration.d.ts, from wrangler.jsonc
	$(call each-app,types-app)

types-app:
	$(WRANGLER) types worker/worker-configuration.d.ts --env-file .dev.vars.example

typecheck-app: types-app

# The plugin writes the chosen environment's config into dist/ at build time, and wrangler
# deploys what dist/ says. Building and deploying in one target is what keeps a development
# build from going out under the production name. An app that fails stops the rest.
deploy: deploy-branch ## Build every app for ENV (development or production) and deploy it
	$(call each-app,deploy-app)

deploy-app:
	CLOUDFLARE_ENV=$(ENV) $(MAKE) --no-print-directory build-app
	$(WRANGLER) deploy
