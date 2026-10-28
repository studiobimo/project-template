# Managed by studiobimo/project-template (profile gcp); change it there.
# vite.mk includes it. Cloud Run's own targets, and its part of the shared ones.

# The client builds into dist/client and the server, bundled into one file, into
# dist/server. Only the client is downloaded by browsers, so only it has a budget.
BUNDLE_DIR := dist/client
TSC_PROJECTS += server

TOFU := cd $(ROOT)/infra && $(MISE) exec -- tofu

# A value from infra/project.auto.tfvars.json, the file OpenTofu reads its variables from:
# one place for the project, region and service name. It is a shell substitution, so it is
# read when a recipe runs rather than every time make starts.
setting = $$(cd $(ROOT) && $(MISE) exec -- node -p "require('./infra/project.auto.tfvars.json').$(1)")

.PHONY: build-server start deploy node-image-check infra-fmt infra-fmt-check infra-bootstrap infra-plan infra-apply infra-github

build: build-server
ci: node-image-check infra-fmt-check

build-server: ## Bundle server/index.ts and what it imports into dist/server/index.mjs
	$(PNPM) exec vite build --config .devtools/host/server.ts

start: build ## Run the production build as Cloud Run runs it, on PORT or 8080
	cd $(ROOT) && $(MISE) exec -- node --enable-source-maps dist/server/index.mjs

# The image copies Node from the official image's exact tag; mise.toml pins the Node that
# builds and tests the app. They change together, so production runs what was tested.
node-image-check: ## Fail when the Dockerfile's Node is not the one mise.toml pins
	@want="$$(cd $(ROOT) && $(MISE) exec -- node -p process.versions.node)"; \
		have="$$(sed -n 's/^FROM node:\([0-9][0-9.]*\)-.*/\1/p' $(ROOT)/Dockerfile)"; \
		[ "$${have}" = "$${want}" ] || { echo "✖ the Dockerfile copies Node $${have:-(no FROM node:<version>-…)}, \
	but mise.toml pins $${want}: change both in one commit" >&2; exit 1; }

# The image is built by Cloud Build from the Dockerfile and dist/ alone (.gcloudignore), so
# the build here is what ships. The client is the same build in every environment: what
# differs per environment belongs on the service, in infra/.
deploy: ## Build, then deploy it to Cloud Run as <service>-ENV (ENV is staging or production)
	@case "$(ENV)" in staging|production) ;; \
		*) echo "✖ usage: make -C .devtools deploy ENV=staging|production" >&2; exit 1 ;; esac
	@command -v gcloud >/dev/null || \
		{ echo "✖ deploying needs gcloud: https://cloud.google.com/sdk/docs/install" >&2; exit 1; }
	$(MAKE) --no-print-directory build
	cd $(ROOT) && project="$(call setting,project)" && gcloud run deploy "$(call setting,service)-$(ENV)" \
		--source . --project "$${project}" --region "$(call setting,region)" \
		--build-service-account "projects/$${project}/serviceAccounts/builder@$${project}.iam.gserviceaccount.com" \
		--quiet

infra-fmt: ## Format infra/ with tofu fmt
	$(TOFU) fmt -recursive

infra-fmt-check: ## Fail on files in infra/ that tofu fmt would change
	$(TOFU) fmt -recursive -check -diff

# OpenTofu keeps its state in a bucket, which has to exist before OpenTofu can run.
infra-bootstrap: ## Once per GCP project: create the versioned bucket OpenTofu keeps its state in
	cd $(ROOT) && project="$(call setting,project)" && bucket="gs://$${project}-tofu-state" \
		&& gcloud storage buckets create "$${bucket}" --project "$${project}" --location "$(call setting,region)" \
			--uniform-bucket-level-access --public-access-prevention \
		&& gcloud storage buckets update "$${bucket}" --versioning

infra-plan: ## Show what OpenTofu would change in the GCP project
	$(TOFU) init -input=false
	$(TOFU) plan -input=false

infra-apply: ## Apply infra/ to the GCP project
	$(TOFU) init -input=false
	$(TOFU) apply -input=false

# Neither value is a secret: impersonating the account still takes a token from a workflow
# in this repository, in a GitHub environment.
infra-github: ## Set the repository variables deploy.yml signs in to GCP with, from OpenTofu's outputs
	cd $(ROOT) && gh variable set GCP_WORKLOAD_IDENTITY_PROVIDER \
		--body "$$($(TOFU) output -raw workload_identity_provider)"
	cd $(ROOT) && gh variable set GCP_SERVICE_ACCOUNT --body "$$($(TOFU) output -raw deployer)"
