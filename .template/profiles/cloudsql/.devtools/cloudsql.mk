# Managed by studiobimo/project-template (profile cloudsql); change it there.
# base.mk includes it when it exists. It needs the gcp-infra profile's infra/ and targets.

.PHONY: cloudsql-gen cloudsql-adk-gen

cloudsql-gen: ## Write infra/cloudsql.tf: a Postgres instance per environment, where there is none
	$(MISE_EXEC) node $(ROOT)/.devtools/cloudsql/gen.mjs

cloudsql-adk-gen: ## With the adk profile: keep the worker's ADK sessions in Postgres, with the connection settings on its service
	$(MISE_EXEC) node $(ROOT)/.devtools/cloudsql/gen.mjs adk
