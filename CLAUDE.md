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
| DATADIR | /home/thomas/dockdata |

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
  - "traefik.http.routers.<app>-secure.rule=Host(`<sub>.mecloud.win`)"
  - "traefik.http.routers.<app>-secure.entrypoints=https"
  - "traefik.http.routers.<app>-secure.tls=true"
  - "traefik.http.routers.<app>-secure.tls.certresolver=cloudflare"
  - "traefik.http.services.<app>-service.loadbalancer.server.port=<port>"
  - "traefik.http.routers.<app>-secure.middlewares=sslheader@docker"
```

## Servermiljö

- **Host**: Raspberry Pi, arm64, Linux 6.8.0-raspi
- **Host IP**: 192.168.0.143
- **Node**: v18.19.1
- **Docker**: v29.2.1 / docker compose v5.0.2
