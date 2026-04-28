include versions.env
export

IMAGE_NAME    := cv-site
GIT_COMMIT    := $(shell git rev-parse --short HEAD)
BUILD_DATE    := $(shell date -u +'%Y-%m-%dT%H:%M:%SZ')
IMAGE_VERSION := $(shell cat VERSION)

.PHONY: help dev build run stop lint security release

help:
	@grep -Eh '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

dev: ## Run Hugo dev server with drafts enabled
	hugo server -D

build: ## Build the Docker image
	docker build \
		--build-arg HUGO_VERSION=$(HUGO_VERSION) \
		--build-arg NGINX_VERSION=$(NGINX_VERSION) \
		--build-arg IMAGE_VERSION=$(IMAGE_VERSION) \
		--build-arg GIT_COMMIT=$(GIT_COMMIT) \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		-t $(IMAGE_NAME):$(IMAGE_VERSION) \
		-t $(IMAGE_NAME):dev .

run: ## Run the Docker image locally on port 8080
	docker run --rm -p 8080:8080 $(IMAGE_NAME):dev

stop: ## Stop any running cv-site containers
	docker ps -q --filter ancestor=$(IMAGE_NAME):dev | xargs -r docker stop

lint: ## Run all pre-commit hooks
	pre-commit run --all-files

release: ## Tag and push a release from main
	@test "$$(git branch --show-current)" = "main" || (echo "Must be on main branch"; exit 1)
	@test -z "$$(git status --porcelain)" || (echo "Working tree is dirty"; exit 1)
	@git fetch origin main
	@test "$$(git rev-list HEAD..origin/main --count)" = "0" || (echo "Behind origin/main, pull first"; exit 1)
	git tag v$(IMAGE_VERSION)
	git push origin v$(IMAGE_VERSION)
