# =============================================================================
# docker2/Makefile – Dagliga operationer
# Användning: make <target>  (kör från ~/docker2)
# =============================================================================

PROJECTS := traefik portainer sftp homer nintendo_switch smart-home music torrents etc claude_build networks

.PHONY: help setup validate up down restart pull logs ps networks clean

help:
	@echo ""
	@echo "Tillgängliga kommandon:"
	@echo ""
	@echo "  make setup       – Kör bootstrap (nätverk, rättigheter, kataloger)"
	@echo "  make validate    – Validera alla Docker Compose-filer (syntax + schema)"
	@echo "  make up          – Starta alla stackar"
	@echo "  make down        – Stoppa alla stackar"
	@echo "  make restart     – Starta om alla stackar"
	@echo "  make pull        – Hämta senaste images för alla stackar"
	@echo "  make logs        – Visa logs för alla containers"
	@echo "  make ps          – Visa status för alla containers"
	@echo "  make networks    – Skapa/verifiera alla Docker-nätverk"
	@echo "  make clean       – Ta bort oanvända images och volumes"
	@echo ""
	@echo "  make up-<stack>       – Starta en specifik stack,  ex: make up-traefik"
	@echo "  make down-<stack>     – Stoppa en specifik stack,  ex: make down-music"
	@echo "  make restart-<stack>  – Starta om en specifik stack"
	@echo "  make logs-<stack>     – Visa logs för en specifik stack"
	@echo ""

# -----------------------------------------------------------------------------
# Bootstrap
# -----------------------------------------------------------------------------
setup:
	@bash setup.sh

# -----------------------------------------------------------------------------
# Validering
# -----------------------------------------------------------------------------
validate:
	@echo "Validerar Docker Compose-filer..."
	@errors=0; \
	for f in $$(find . -maxdepth 2 -name "docker-compose*.yml" | sort); do \
		if docker compose -f "$$f" config > /dev/null 2>&1; then \
			printf "  [OK]  $$f\n"; \
		else \
			printf "  [!!]  MISSLYCKADES: $$f\n"; \
			docker compose -f "$$f" config 2>&1 | sed 's/^/         /'; \
			errors=$$((errors + 1)); \
		fi; \
	done; \
	if [ "$$errors" -gt 0 ]; then \
		echo ""; \
		echo "$$errors fil(er) misslyckades med validering."; \
		exit 1; \
	fi; \
	echo ""; \
	echo "Alla compose-filer är giltiga."

# -----------------------------------------------------------------------------
# Nätverk
# -----------------------------------------------------------------------------
networks:
	@echo "Skapar Docker-nätverk..."
	@for dir in */; do \
		name=$$(basename "$$dir"); \
		[ -f "$${dir}docker-compose.yml" ] || continue; \
		netname=$$(echo "$$name" | tr '-' '_'); \
		docker network inspect "$$netname" > /dev/null 2>&1 \
			&& echo "  [OK]  $$netname finns redan" \
			|| (docker network create "$$netname" && echo "  [+]   $$netname skapades"); \
	done
	@docker network inspect traefik > /dev/null 2>&1 \
		&& echo "  [OK]  traefik finns redan" \
		|| (docker network create traefik && echo "  [+]   traefik skapades")

# -----------------------------------------------------------------------------
# Starta – traefik måste alltid vara först
# -----------------------------------------------------------------------------
up:
	@echo "Startar traefik..."
	@docker compose -f traefik/docker-compose-traefik.yml up -d
	@for stack in $(filter-out traefik,$(PROJECTS)); do \
		[ -f "$$stack/docker-compose.yml" ] || continue; \
		echo "Startar $$stack..."; \
		docker compose -f "$$stack/docker-compose.yml" up -d; \
	done

down:
	@for stack in $(PROJECTS); do \
		[ -f "$$stack/docker-compose.yml" ] || continue; \
		echo "Stoppar $$stack..."; \
		docker compose -f "$$stack/docker-compose.yml" down; \
	done

restart:
	@$(MAKE) down
	@$(MAKE) up

pull:
	@for stack in $(PROJECTS); do \
		[ -f "$$stack/docker-compose.yml" ] || continue; \
		echo "Hämtar images för $$stack..."; \
		docker compose -f "$$stack/docker-compose.yml" pull; \
	done

ps:
	@docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

logs:
	@docker compose $(foreach s,$(PROJECTS), $(if $(wildcard $(s)/docker-compose.yml),-f $(s)/docker-compose.yml)) logs -f --tail=50

clean:
	@echo "Rensar oanvända images och volumes..."
	@docker image prune -f
	@docker volume prune -f
	@echo "Klart."

# -----------------------------------------------------------------------------
# Per-stack targets: make up-traefik, make down-music, etc.
# -----------------------------------------------------------------------------
up-%:
	@[ -f "$*/docker-compose.yml" ] \
		&& docker compose -f "$*/docker-compose.yml" up -d \
		|| echo "Ingen docker-compose.yml i $*/"

down-%:
	@[ -f "$*/docker-compose.yml" ] \
		&& docker compose -f "$*/docker-compose.yml" down \
		|| echo "Ingen docker-compose.yml i $*/"

restart-%:
	@$(MAKE) down-$*
	@$(MAKE) up-$*

logs-%:
	@[ -f "$*/docker-compose.yml" ] \
		&& docker compose -f "$*/docker-compose.yml" logs -f --tail=100 \
		|| echo "Ingen docker-compose.yml i $*/"
