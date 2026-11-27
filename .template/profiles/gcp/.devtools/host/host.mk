# Managed by studiobimo/project-template (profile gcp); change it there.
# vite.mk includes it, after the gcp-infra profile's gcp-infra.mk, whose TOFU and setting it
# uses. Cloud Run's own targets, and its part of the shared ones.

# The client builds into dist/client and the server, bundled into one file, into
# dist/server. Only the client is downloaded by browsers, so only it has a budget.
BUNDLE_DIR := dist/client
TSC_PROJECTS += server

# $${have} and $${want} are the shell variables of node-image-check's recipe.
MSG_NODE_MISMATCH = $(GLYPH_FAIL) the Dockerfile copies Node $${have:-(no FROM node:<version>-…)}, \
	but mise.toml pins $${want}: change both in one commit
MSG_NO_GCLOUD := $(GLYPH_FAIL) deploying needs gcloud: https://cloud.google.com/sdk/docs/install

.PHONY: build-server start deploy node-image-check

build-app: build-server
ci: node-image-check

build-server: ## Bundle server/index.ts and what it imports into dist/server/index.mjs
	$(APP_PNPM) exec vite build --config $(ROOT)/.devtools/host/server.ts

start: build-app ## Run the production build as Cloud Run runs it, on PORT or 8080
	$(APP_CD) && $(MISE_EXEC) node --enable-source-maps dist/server/index.mjs

# The image copies Node from the official image's exact tag; mise.toml pins the Node that
# builds and tests the app. They change together, so production runs what was tested.
node-image-check: ## Fail when the Dockerfile's Node is not the one mise.toml pins
	@want="$$(cd $(ROOT) && $(MISE_EXEC) node -p process.versions.node)"; \
		have="$$(sed -n 's/^FROM node:\([0-9][0-9.]*\)-.*/\1/p' $(ROOT)/Dockerfile)"; \
		[ "$${have}" = "$${want}" ] || { echo "$(MSG_NODE_MISMATCH)" >&2; exit 1; }

# The image is built by Cloud Build from the Dockerfile and dist/ alone (.gcloudignore), so
# the build here is what ships. The client is the same build in every environment: what
# differs per environment belongs on the service, in infra/.
deploy: deploy-branch ## Build, then deploy to Cloud Run as <service>-ENV (development or production)
	@command -v gcloud >/dev/null || { echo "$(MSG_NO_GCLOUD)" >&2; exit 1; }
	$(MAKE) --no-print-directory build
	cd $(ROOT) && project="$(call setting,project)" && gcloud run deploy "$(call setting,service)-$(ENV)" \
		--source . --project "$${project}" --region "$(call setting,region)" \
		--build-service-account "projects/$${project}/serviceAccounts/builder@$${project}.iam.gserviceaccount.com" \
		--quiet
