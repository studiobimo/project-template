# Managed by studiobimo/project-template (profile cloudsql); change it there.
# base.mk includes it when it exists. It needs the gcp-infra profile's infra/ and targets.

.PHONY: cloudsql-gen

cloudsql-gen: ## Write infra/cloudsql.tf: a Postgres instance per environment, where there is none
	$(MISE_EXEC) node $(ROOT)/.devtools/cloudsql/gen.mjs
