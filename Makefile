# Usage: make <target> [p=profile1,profile2]
#   make up               start the profiles listed in .env (COMPOSE_PROFILES)
#   make up p=postgres,s3 start only these profiles
#   make all              start everything

COMPOSE := docker compose
ifdef p
  export COMPOSE_PROFILES := $(p)
endif

.DEFAULT_GOAL := help
.PHONY: help env up all down stop ps logs pull config clean

help: ## Show this help
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*## "}{printf "  \033[36m%-8s\033[0m %s\n",$$1,$$2}'
	@echo "\n  Profiles: postgres redis s3 nsq mongo mail qr   (e.g. make up p=postgres,redis)"

env: ## Create .env from .env.example if missing
	@test -f .env || (cp .env.example .env && echo "Created .env - edit it to taste")

up: env ## Start selected profiles and wait until healthy
	$(COMPOSE) up -d --wait
	@$(COMPOSE) ps

all: env ## Start every service
	COMPOSE_PROFILES='*' $(COMPOSE) up -d --wait
	@COMPOSE_PROFILES='*' $(COMPOSE) ps

down: ## Stop and remove containers (keeps data)
	COMPOSE_PROFILES='*' $(COMPOSE) down

stop: ## Stop containers without removing them
	COMPOSE_PROFILES='*' $(COMPOSE) stop

ps: ## List running services
	COMPOSE_PROFILES='*' $(COMPOSE) ps

logs: ## Follow logs (make logs s=postgres)
	COMPOSE_PROFILES='*' $(COMPOSE) logs -f --tail=100 $(s)

pull: ## Pull the latest pinned images
	$(COMPOSE) pull

config: ## Validate and print the resolved compose file
	COMPOSE_PROFILES='*' $(COMPOSE) config

clean: ## Stop everything AND delete all data volumes
	@read -p "Delete ALL data volumes? [y/N] " a && [ "$$a" = y ]
	COMPOSE_PROFILES='*' $(COMPOSE) down -v
