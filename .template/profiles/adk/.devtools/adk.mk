# Managed by studiobimo/project-template (profile adk); change it there.
# Include it from Makefile after typescript.mk, whose PNPM and image target it uses, and
# after base.mk, which includes gcp-infra.mk for `setting`.

ADK_SERVICES := ingress worker
ADK_WORKER := ./services/worker
ADK_LOCAL := ./packages/local

MSG_ADK_USAGE = $(GLYPH_FAIL) usage: $(DEVTOOLS) adk-deploy ENV=<environment>
MSG_NO_GCLOUD_ADK := $(GLYPH_FAIL) deploying needs gcloud and docker: https://cloud.google.com/sdk/docs/install

.PHONY: adk-gen adk-dev adk-eval adk-graphs adk-graphs-check adk-deploy

ci: adk-graphs-check

adk-gen: ## Once: write the first agent workspace (contracts, platform, ingress, worker, local, infra)
	$(MISE_EXEC) node $(ROOT)/.devtools/adk/gen.mjs agents

adk-dev: build ## Run ingress -> bus -> worker in one process on PORT (8080) with a scripted judge, no GCP
	$(PNPM) --filter $(ADK_LOCAL) run start

adk-eval: build ## Score evals/cases.json against the real judge on Vertex AI (needs gcloud auth application-default login)
	$(PNPM) --filter $(ADK_WORKER) run eval

adk-graphs: build ## Write each workflow's nodes and edges to graphs/<workflow>.json, for a React Flow viewer
	$(PNPM) --filter $(ADK_WORKER) run graphs

adk-graphs-check: build ## Fail when graphs/ is not what the workflows are
	$(PNPM) --filter $(ADK_WORKER) run graphs:check

adk-deploy: ## Build both images, push them to Artifact Registry and roll them out: ENV=development|production
	@test -n "$(ENV)" || { echo "$(MSG_ADK_USAGE)" >&2; exit 2; }
	@command -v gcloud >/dev/null && command -v docker >/dev/null || { echo "$(MSG_NO_GCLOUD_ADK)" >&2; exit 1; }
	@project="$(call setting,project)"; region="$(call setting,region)"; service="$(call setting,service)"; \
		tag="$$(cd $(ROOT) && git rev-parse --short HEAD)"; \
		for name in $(ADK_SERVICES); do \
			image="$${region}-docker.pkg.dev/$${project}/cloud-run-source-deploy/$${name}:$${tag}"; \
			$(MAKE) --no-print-directory image SERVICE=services/$${name} \
				&& docker tag "$${name}" "$${image}" && docker push "$${image}" \
				&& gcloud run services update "$${service}-$${name}-$(ENV)" --project "$${project}" \
					--region "$${region}" --container app --image "$${image}" || exit 1; \
		done
