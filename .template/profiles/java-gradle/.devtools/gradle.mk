# Managed by studiobimo/project-template (profile java-gradle); change it there. Include it
# from Makefile, after base.mk, and add the project's own targets (and their .PHONY) there.

GRADLE := cd $(ROOT) && JAVA_HOME="$$(/usr/libexec/java_home -v $$(cat .java-version) 2>/dev/null || echo $$JAVA_HOME)" ./gradlew

.PHONY: fmt test build check client-test lock stray kill-stray run-fabric run-neoforge run-fabric-server run-neoforge-server clean

fmt: ## Format Java sources
	$(GRADLE) spotlessApply

test: ## Unit tests
	$(GRADLE) :common:check

build: ## Compile, lint (Error Prone), test and package both loaders
	$(GRADLE) build

check: lint build ## Everything CI runs

client-test: ## Run the client GameTest in a real client (opens a window, so it is not part of check)
	$(GRADLE) :fabric:runClientGameTest

lock: lock-tools ## Refresh every lockfile and the sha256 dependency verification after a version change
	$(GRADLE) --write-verification-metadata sha256 --refresh-dependencies resolveAndLockAll buildEnvironment build --write-locks

stray: ## List JVMs a dev run or GameTest left behind
	@$(CURDIR)/scripts/stray-java.sh || true

kill-stray: ## Stop JVMs a dev run or GameTest left behind
	@$(CURDIR)/scripts/stray-java.sh --kill

run-fabric: ## Launch the Fabric dev client
	$(GRADLE) :fabric:runClient

run-neoforge: ## Launch the NeoForge dev client
	$(GRADLE) :neoforge:runClient

run-fabric-server: ## Launch the Fabric dev server (headless)
	$(GRADLE) :fabric:runServer

run-neoforge-server: ## Launch the NeoForge dev server (headless)
	$(GRADLE) :neoforge:runServer

clean: ## Remove build outputs
	$(GRADLE) clean
