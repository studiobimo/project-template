# Managed by studiobimo/project-template (profile phoenix); change it there.
# Include it from Makefile after adk.mk, whose services it adds the eval worker to.

ADK_SERVICES += eval

.PHONY: phoenix-gen

phoenix-gen: ## Once: Phoenix on Cloud Run, the eval worker and the Phoenix exporter on the collector
	$(MISE_EXEC) node $(ROOT)/.devtools/phoenix/gen.mjs
