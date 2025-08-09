SHELL:=bash

.DEFAULT_GOAL := help


.PHONY: help
help: ## Available commands
	@echo "Available commands:"
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[0;33m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
	@echo ""


.PHONY: up down ps logs macos-deps macos-run web-run backend-run dc-build dc-up dc-down dc-logs open-web dc-up-open check-docker backend-run-local-bg dev-open

up: check-docker ## Start the services
	docker compose -f deployments/docker-compose.yaml up -d

down: ## Stop the services
	docker compose -f deployments/docker-compose.yaml down

ps: ## List the services
	docker compose -f deployments/docker-compose.yaml ps

logs: ## Follow the logs
	docker compose -f deployments/docker-compose.yaml logs -f

dc-build: check-docker ## Build docker images (backend, web)
	docker compose -f deployments/docker-compose.yaml build --no-cache

dc-up: check-docker ## Up all stack (redis, backend, web)
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

check-docker:
	@docker info >/dev/null 2>&1 || { echo "Docker is not running. Start Docker Desktop and retry."; exit 1; }

macos-deps: ## Install macOS toolchain dependencies (Xcode/CLT) and enable Flutter macOS
	@echo "Checking Xcode installation..."
	@if [ ! -d "/Applications/Xcode.app" ]; then \
		echo "Xcode not found. Please install Xcode from App Store first."; \
		exit 1; \
	fi
	@echo "Installing Xcode Command Line Tools (if needed)"
	-xcode-select --install || true
	@echo "Accepting Xcode license (requires sudo)"
	-sudo xcodebuild -license accept || true
	@echo "Switching xcode-select to /Applications/Xcode.app"
	-sudo xcode-select -switch /Applications/Xcode.app/Contents/Developer || true
	@echo "Installing CocoaPods..."
	-brew install cocoapods || sudo gem install cocoapods || true
	@echo "Enable Flutter macOS desktop"
	cd app && flutter config --enable-macos-desktop && flutter doctor -v

macos-run: ## Run Flutter app on macOS (falls back to Chrome if Xcode not installed)
	@echo "Checking Xcode setup..."
	@if ! command -v xcodebuild >/dev/null 2>&1; then \
		echo "Xcode not found. Please run 'make macos-deps' first."; \
		exit 1; \
	fi
	@if [ ! -d "/Applications/Xcode.app" ]; then \
		echo "Xcode.app not found. Please install Xcode from App Store first."; \
		exit 1; \
	fi
	@echo "Running Flutter app on macOS..."
	cd app && flutter run -d macos --dart-define=API_BASE_URL=http://localhost:8080

backend-run-local-bg: ## Run backend locally in background on 127.0.0.1:8080 (without Redis)
	@echo "Starting backend locally (no Redis) on 127.0.0.1:8080 ..."
	@cd backend && nohup $(MAKE) run HTTP_ADDR=127.0.0.1:8080 REDIS_ADDR= >/dev/null 2>&1 &
	@echo "Backend started in background."

dev-open: ## One command: run app (Docker stack if available, otherwise local backend + Chrome)
	@if docker info >/dev/null 2>&1; then \
		$(MAKE) dc-up-open; \
	else \
		echo "Docker not running; starting local backend and opening Chrome"; \
		$(MAKE) backend-run-local-bg; \
		cd app && flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8080; \
	fi

macos-dev: ## Run macOS app with local backend (backend + macOS app)
	@echo "Starting local backend..."
	$(MAKE) backend-run-local-bg
	@echo "Starting macOS app..."
	$(MAKE) macos-run

web-run: ## Run Flutter app in Chrome (quick preview)
	cd app && flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080

backend-run: ## Build and run backend with Redis on 127.0.0.1:8080
	$(MAKE) up
	cd backend && $(MAKE) run HTTP_ADDR=127.0.0.1:8080 REDIS_ADDR=127.0.0.1:6379
