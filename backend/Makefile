BIN=bin/server
PKG=./cmd/server

# Defaults (can be overridden via environment or make vars)
HTTP_ADDR ?= 127.0.0.1:8080
APP_ENV ?= dev
LOG_LEVEL ?= info
REDIS_ADDR ?=
REDIS_DB ?= 0
REDIS_PASSWORD ?=

.PHONY: build run test clean fmt vet

build:
	@mkdir -p bin
	@go build -trimpath -ldflags "-s -w" -o $(BIN) $(PKG)

run: build
	@echo "HTTP_ADDR=$(HTTP_ADDR)"
	@HTTP_ADDR=$(HTTP_ADDR) APP_ENV=$(APP_ENV) LOG_LEVEL=$(LOG_LEVEL) REDIS_ADDR=$(REDIS_ADDR) REDIS_DB=$(REDIS_DB) REDIS_PASSWORD=$(REDIS_PASSWORD) ./$(BIN)

test:
	@go test ./...

fmt:
	@gofmt -s -w .

vet:
	@go vet ./...

clean:
	@rm -rf bin
