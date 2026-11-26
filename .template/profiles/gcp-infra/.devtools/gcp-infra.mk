# Managed by studiobimo/project-template (profile gcp-infra); change it there.
# base.mk includes it when it exists. OpenTofu's targets for infra/, which every Cloud Run
# project shares, and the make settings the hosting profile builds on.

TOFU := cd $(ROOT)/infra && $(MISE_EXEC) tofu

# A value from infra/project.auto.tfvars.json, the file OpenTofu reads its variables from:
# one place for the project, region and service name. It is a shell substitution, so it is
# read when a recipe runs rather than every time make starts.
setting = $$(cd $(ROOT) && $(MISE_EXEC) node -p "require('./infra/project.auto.tfvars.json').$(1)")

.PHONY: infra-gen infra-fmt infra-fmt-check infra-bootstrap infra-plan infra-apply infra-github

ci: infra-fmt-check

infra-gen: ## Write a first infra/ for this repository, where there is none
	$(MISE_EXEC) node $(ROOT)/.devtools/gcp-infra/gen.mjs

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
