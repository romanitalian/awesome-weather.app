SHELL:=bash

.DEFAULT_GOAL := help


.PHONY: help
help: ## Available commands
	@echo "Available commands:"
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[0;33m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
	@echo ""


.PHONY: up down ps logs macos-deps macos-run web-run backend-run dc-build dc-up dc-down dc-logs open-web dc-up-open

up: ## Start the services
	docker compose -f deployments/docker-compose.yaml up -d

down: ## Stop the services
	docker compose -f deployments/docker-compose.yaml down

ps: ## List the services
	docker compose -f deployments/docker-compose.yaml ps

logs: ## Follow the logs
	docker compose -f deployments/docker-compose.yaml logs -f

dc-build: ## Build docker images (backend, web)
	docker compose -f deployments/docker-compose.yaml build --no-cache

dc-up: ## Up all stack (redis, backend, web)
	docker compose -f deployments/docker-compose.yaml up -d

dc-down: ## Down all stack
	docker compose -f deployments/docker-compose.yaml down

dc-logs: ## Follow logs for all services
	docker compose -f deployments/docker-compose.yaml logs -f

open-web: ## Open web client in default browser
	@open http://localhost:8081 || xdg-open http://localhost:8081 || true

dc-up-open: ## Up all stack and open web client
	$(MAKE) dc-up
	$(MAKE) open-web

macos-deps: ## Install macOS toolchain dependencies (Xcode/CLT) and enable Flutter macOS
	@echo "Installing Xcode Command Line Tools (if needed)"
	-xcode-select --install || true
	@echo "Accepting Xcode license (requires sudo)"
	-sudo xcodebuild -license accept || true
	@echo "Switching xcode-select to /Applications/Xcode.app"
	-sudo xcode-select -switch /Applications/Xcode.app/Contents/Developer || true
	@echo "Enable Flutter macOS desktop"
	cd app && flutter config --enable-macos-desktop && flutter doctor -v

macos-run: ## Run Flutter app on macOS (requires Xcode)
	cd app && flutter run -d macos --dart-define=API_BASE_URL=http://127.0.0.1:8080

web-run: ## Run Flutter app in Chrome (quick preview)
	cd app && flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8080

backend-run: ## Build and run backend with Redis on 127.0.0.1:8080
	$(MAKE) up
	cd backend && $(MAKE) run HTTP_ADDR=127.0.0.1:8080 REDIS_ADDR=127.0.0.1:6379
