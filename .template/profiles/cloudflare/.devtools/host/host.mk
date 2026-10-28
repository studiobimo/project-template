# Managed by studiobimo/project-template (profile cloudflare); change it there.
# vite.mk includes it. Cloudflare's own targets, and its part of the shared ones.

WRANGLER := $(PNPM) exec wrangler

# The plugin builds the client into dist/client and the Worker beside it. Only the client
# is downloaded by browsers, so only it has a budget.
BUNDLE_DIR := dist/client
TSC_PROJECTS += worker

.PHONY: types deploy

# The Env type is generated, not committed. Secret names come from .dev.vars.example, so CI,
# which has no .dev.vars, types the same Env as a laptop does.
types: ## Generate the Worker's Env type, worker/worker-configuration.d.ts, from wrangler.jsonc
	$(WRANGLER) types worker/worker-configuration.d.ts --env-file .dev.vars.example

typecheck: types

# The plugin writes the chosen environment's config into dist/ at build time, and wrangler
# deploys what dist/ says. Building and deploying in one target is what keeps a staging
# build from going out under the production name.
deploy: ## Build for ENV (staging or production) and deploy it
	@case "$(ENV)" in staging|production) ;; \
		*) echo "✖ usage: make -C .devtools deploy ENV=staging|production" >&2; exit 1 ;; esac
	CLOUDFLARE_ENV=$(ENV) $(MAKE) --no-print-directory build
	$(WRANGLER) deploy
