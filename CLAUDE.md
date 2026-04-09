# docker2 – Claude Code Instructions

Ny organiserad Docker-struktur för Raspberry Pi-servern.
Varje projektmapp är en självständig stack med egna compose-filer.

## Automation

| Fil | Syfte |
|-----|-------|
| `setup.sh` | Bootstrap – kör efter git clone. Skapar nätverk, kataloger, rättigheter, .env-filer |
| `Makefile` | Dagliga operationer: `make up/down/restart/pull/logs/ps` |
| `.env.example` | Mall för globala hemligheter – kopieras automatiskt till `.env` av setup.sh |
| `<stack>/.env.example` | Mall per stack – kopieras till `.env` av setup.sh om `.env` saknas |

### Flöde vid ny server / git clone
```bash
git clone <repo> ~/docker2
cd ~/docker2
bash setup.sh        # Skapar allt automatiskt
# Fyll i .env-filer som markerats med [--]
make up              # Startar alla stackar (traefik alltid först)
```

### Lägga till ny projektstack
1. Skapa mapp med `docker-compose.yml` i `~/docker2/<projektnamn>/`
2. Lägg till `.env.example` i mappen
3. Kör `bash setup.sh` – nätverket skapas automatiskt
4. Lägg till projektnamnet i `Makefile` under `PROJECTS`
5. Lägg till nätverket i `traefik/docker-compose-traefik.yml`

## Mappstruktur

| Mapp | Tjänster | Status |
|------|----------|--------|
| `traefik/` | Traefik reverse proxy | Klar |
| `portainer/` | Portainer CE | Klar |
| `sftp/` | SFTP-server (Alpine) | Klar |
| `homer/` | Homer dashboard | Påbörjad |
| `nintendo_switch/` | Aerofoil, Transmission, Prowlarr, Flaresolverr | Påbörjad |
| `smart-home/` | Home Assistant, Music Assistant, Matter, Mosquitto, Wyoming | Inte klar |
| `music/` | Navidrome, Beets, Metube | Inte klar |
| `claude_build/` | Dashboard, Elitetube, Forsaljning, Tidsrapport | Inte klar |
| `torrent/` | Deluge | Inte klar |
| `etc/` | Lidarr, Booklore | Inte klar |
| `networks/` | NetAlertX, WatchYourLAN | Inte klar |

## Nätverksarkitektur

Varje projektmapp har ett eget isolerat Docker-nätverk (samma namn som mappen).
Alla tjänster är även anslutna till det externa `traefik`-nätverket för reverse proxy.
Bara tjänster som behöver kommunicera med varandra delar nätverk.

### Nätverkskarta

| Projekt | Nätverk | Motivering |
|---------|---------|------------|
| `nintendo_switch` | `nintendo_switch` | prowlarr ↔ flaresolverr, aerofoil ↔ transmission |
| `smart-home` | `smart_home` | HA ↔ mosquitto, HA ↔ musicassistant, HA ↔ matterserver, HA ↔ wyoming-* |
| `music` | `music` | navidrome ↔ beets, metube delar volym |
| `torrent` | `torrent` | Isolerat, deluge ensamt |
| `etc` | `etc` | lidarr + booklore — om lidarr ska styra deluge: lägg även till torrent-nätverket |
| `claude_build` | `claude_build` | Alla appar kan kommunicera internt |
| `networks` | `networks` | netalertx + watchyourlan |

### Nätverk-mall per projekt (i docker-compose.yml)

```yaml
networks:
  <projektnamn>:
    name: <projektnamn>
    driver: bridge
  traefik:
    external: true
```

## Viktiga miljövariabler

Globala variabler som återanvänds i alla stacks:

| Variabel | Värde |
|----------|-------|
| PUID | 1000 |
| PGID | 1000 |
| TZ | Europe/Stockholm |
| DOMAIN | mecloud.win |
| DATADIR | /home/thomas/dockdata2 |

## Konventioner

- Varje projektmapp har en `docker-compose.yml` som inkluderar sub-compose-filer med `include:`
- Sub-compose-filer ligger i undermappar: `<tjänst>/docker-compose-<tjänst>.yml`
- Persistenta data lagras i named volumes eller under `$DATADIR/<tjänst>/`
- Känsliga variabler i `.env` per projektmapp
- Starta alltid via `docker compose`, aldrig manuellt `docker run`
- Bygga & starta: `docker compose up -d`

## Traefik-mall för labels

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.<app>-secure.rule=Host(`<sub>.$DOMAIN`)"
  - "traefik.http.routers.<app>-secure.entrypoints=https"
  - "traefik.http.routers.<app>-secure.tls=true"
  - "traefik.http.routers.<app>-secure.tls.certresolver=cloudflare"
  - "traefik.http.services.<app>-service.loadbalancer.server.port=<port>"
  - "traefik.http.routers.<app>-secure.middlewares=sslheader@docker"
```

## Servermiljö

- **Host**: Raspberry Pi 5, arm64, Linux 6.8.0-raspi
- **Host IP**: 192.168.0.143
- **Node**: v18.19.1
- **Docker**: v29.2.1 / docker compose v5.0.2

## Git-workflow

- Commita alltid direkt till `main`, inga PRs
- Hook blockerar direkteditering på main — skapa alltid en feature-branch, committa, merga till main

## k3s-status (2026-04-09)

Klustret kör i produktion parallellt med Docker Traefik.

| Nod | IP | Roll |
|-----|----|------|
| pi-master (Raspberry Pi) | 192.168.0.143 | control-plane |
| pc-worker (Ubuntu PC) | 192.168.0.156 | worker |

Pods på **pi-master**: homer, navidrome, tidsrapport, headlamp, sftp, samba
Pods på **pc-worker**: aerofoil, metube, transmission, prowlarr, flaresolverr, elitetube

Docker Traefik proxar till k3s NodePorts — config i `traefik/config.yml`.
HA-stacken (homeassistant, mosquitto, musicassistant, matterserver, wyoming) kvarstår i Docker pga USB-passthrough + host network.

## Aktiva tjänster

| Tjänst | URL | Kör på |
|--------|-----|--------|
| homer | https://homer.mecloud.win | k3s/pi |
| navidrome | https://navidrome.mecloud.win | k3s/pi |
| tidsrapport | https://tidrapport.mecloud.win | k3s/pi |
| headlamp | https://headlamp.mecloud.win | k3s/pi |
| aerofoil | https://aerofoil.mecloud.win | k3s/pc |
| metube | https://metube.mecloud.win | k3s/pc |
| transmission | https://deluge.mecloud.win | k3s/pc |
| elitetube | https://tube.mecloud.win | k3s/pc |
| homeassistant | https://home.mecloud.win | Docker/pi |
| traefik | intern | Docker/pi |
| portainer | https://portainer.mecloud.win | Docker/pi |

---

# Docker Development

Aktiveras vid: Dockerfile-optimering, docker-compose-konfiguration, multi-stage builds, container-säkerhet, image-storlek.

## Proaktiva varningsflaggor

Flagga alltid utan att bli tillfrågad om:
- `:latest`-tag → föreslå pinning till specifik version
- Ingen `.dockerignore` → skapa en (minst: `.git`, `node_modules`, `.env`)
- `COPY . .` före dependency-installation → cache-bust, omordna
- Körs som root → lägg till `USER`-instruktion, inga undantag i produktion
- Secrets i `ENV`/`ARG` → använd BuildKit secret mounts
- Image över 1GB → multi-stage build krävs
- Ingen `HEALTHCHECK` → lägg till en

## Multi-stage build: Node.js/TypeScript (arm64)

```dockerfile
FROM node:18-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --production=false

FROM deps AS builder
COPY . .
RUN npm run build

FROM node:18-alpine
WORKDIR /app
RUN addgroup -g 1001 -S appgroup && adduser -S appuser -u 1001
COPY --from=builder /app/dist ./dist
COPY --from=deps /app/node_modules ./node_modules
COPY package.json ./
USER appuser
EXPOSE 3000
CMD ["node", "dist/index.js"]
```

**OBS:** Node-version i Docker MÅSTE matcha host (`node --version` = v18.19.1) annars kraschar nativa moduler (better-sqlite3) med `ERR_DLOPEN_FAILED`.

## Layer-optimering

```
ORDNING (minst-föränderligt först):
1. Base image
2. System-dependencies (apt/apk)
3. Package.json + npm install
4. Källkod (COPY . .)

Kombinera RUN-kommandon:
RUN apt-get update && apt-get install -y pkg && rm -rf /var/lib/apt/lists/*
```

## Compose best practices

```yaml
services:
  app:
    image: myapp:1.2.3          # Aldrig :latest i produktion
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    env_file: .env              # Secrets i env_file, inte inline environment
    networks:
      - internal
      - traefik

networks:
  internal:
    name: projectname
    driver: bridge
  traefik:
    external: true
```

## Säkerhetsaudit-checklista

| Check | Allvarlighet | Fix |
|---|---|---|
| Körs som root | Kritisk | `USER nonroot` |
| `:latest`-tag | Hög | Pinna version |
| Secrets i ENV/ARG | Kritisk | BuildKit secret mounts |
| Ingen HEALTHCHECK | Medium | Lägg till |
| `--privileged` | Hög | Undvik, droppa capabilities |
| apt-cache kvar | Låg | `rm -rf /var/lib/apt/lists/*` i samma RUN |

---

# Env & Secrets Manager

Aktiveras vid: .env-filer, secrets-hantering, credential-rotation, säkerhetsaudit av config-filer.

## Rekommenderat flöde

1. Scanna repo efter läckage innan push
2. Prioritera `critical` och `high` först
3. Rotera riktiga credentials och ta bort exponerade värden
4. Uppdatera `.env.example` och `.gitignore`

## Best practices

- Använd `.env.example` med platshållare — aldrig riktiga värden
- `.env` alltid i `.gitignore`
- Variabel-substitution: `${VAR:-default}`
- Dokumentera alla obligatoriska variabler i `.env.example`

## Vanliga fallgropar

- Committa riktiga värden i `.env.example`
- Rotera en tjänst men missa downstream-konsumenter
- Logga secrets under felsökning
- Behandla misstänkta läckage som låg prioritet

## Emergency rotation

1. Återkalla omedelbart hos providern
2. Generera och driftsätt ny credential till alla konsumenter
3. Granska access-loggar för obehörig användning
4. Scanna git-historik och CI-loggar efter det exponerade värdet
5. Dokumentera scope, tidslinje och åtgärder
