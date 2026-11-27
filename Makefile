# Usage: make <target> [p=profile1,profile2] [s="service ..."]
#   make init             pick your services interactively (writes .env)
#   make up               start the profiles in .env (COMPOSE_PROFILES)
#   make up p=postgres,s3 start only these profiles
#   make urls             connection strings for your app's .env

COMPOSE := docker compose
ifdef p
  export COMPOSE_PROFILES := $(p)
endif
ALL := COMPOSE_PROFILES='*'

.DEFAULT_GOAL := help
.PHONY: help init env up all only down stop restart ps logs urls check stats disk prune pull config clean uninstall

help: ## Show this help
	@echo "Usage: make <target> [p=profile,...] [s=\"service ...\"]\n"
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*## "}{printf "  \033[36m%-10s\033[0m %s\n",$$1,$$2}'
	@echo "\n  Profiles: postgres redis s3 nsq mongo mail qr kafka rabbitmq search keycloak observability"

init: ## Pick services interactively, see RAM/disk needs, write .env
	@scripts/init.sh

env:
	@test -f .env || (cp .env.example .env && echo "Created .env from .env.example (run 'make init' to pick services)" >&2)

up: env ## Start the selected profiles and wait until healthy
	$(COMPOSE) up -d --build --wait
	@$(COMPOSE) ps --format 'table {{.Service}}\t{{.Status}}\t{{.Ports}}'
	@echo "\nConnection strings: make urls"

all: env ## Start every service (needs ~4.5 GB RAM, ~14 GB disk)
	$(ALL) $(COMPOSE) up -d --build --wait

only: env ## Start just these services, without admin UIs: make only s="postgres redis"
	@test -n "$(s)" || (echo 'usage: make only s="postgres redis"' && exit 1)
	$(ALL) $(COMPOSE) up -d --build --wait --no-deps $(s)

down: ## Stop and remove containers (data is kept)
	$(ALL) $(COMPOSE) down

stop: ## Pause containers without removing them
	$(ALL) $(COMPOSE) stop

restart: ## Restart services: make restart s=postgres
	$(ALL) $(COMPOSE) restart $(s)

ps: ## List running services
	$(ALL) $(COMPOSE) ps

logs: ## Follow logs: make logs s=postgres
	$(ALL) $(COMPOSE) logs -f --tail=100 $(s)

urls: env ## Print connection strings (make urls > ../my-app/.env.local)
	@scripts/urls.sh

check: env ## Verify each running profile actually works
	@scripts/check.sh

stats: ## Live RAM/CPU per container
	$(ALL) $(COMPOSE) stats

disk: ## How much disk Docker and this stack's data use
	@docker system df
	@echo "\nData volumes of this stack:"
	@docker system df -v | awk '/^VOLUME NAME/{f=1;next} f&&NF==0{exit} f&&index($$1,"'"$${COMPOSE_PROJECT_NAME:-docker-files}"'_")==1{printf "  %-34s %s\n",$$1,$$3; n++} END{if(!n) print "  (none yet)"}'

prune: ## Free disk safely: dangling images + build cache (other images and data untouched)
	docker image prune -f
	docker builder prune -f

pull: ## Pull the pinned images for the selected profiles
	$(COMPOSE) pull --ignore-buildable

config: ## Validate and print the resolved compose file
	$(ALL) $(COMPOSE) config

clean: ## Stop everything AND delete all data volumes
	@read -p "Delete ALL data in this stack's volumes? [y/N] " a && [ "$$a" = y ]
	$(ALL) $(COMPOSE) down -v

uninstall: ## Remove containers, data AND images of this stack (frees the most disk)
	@read -p "Remove containers, data volumes and images of this stack? [y/N] " a && [ "$$a" = y ]
	$(ALL) $(COMPOSE) down -v --rmi all
