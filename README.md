# docker2 – Självhostad server-stack

En organiserad Docker-setup för Raspberry Pi (arm64) eller annan Linux-server.
Strukturerad som separata stackar per kategori — varje mapp är en självständig enhet.

## Innehall

| Stack | Tjänster |
|-------|----------|
| `traefik/` | Reverse proxy med automatisk SSL (Cloudflare DNS-challenge) |
| `portainer/` | Webb-UI for Docker-hantering |
| `sftp/` | SFTP-server (Alpine) |
| `homer/` | Startsida / dashboard |
| `smart-home/` | Home Assistant, Music Assistant, Matter Server, Mosquitto, Wyoming |
| `nintendo_switch/` | Aerofoil, Transmission, Prowlarr, Flaresolverr |
| `music/` | Navidrome, Beets, Metube |
| `torrents/` | Deluge |
| `etc/` | Lidarr, Booklore |
| `networks/` | NetAlertX, WatchYourLAN |
| `claude_build/` | Elitetube, Tidsrapport m.fl. egna appar |

---

## Forutsattningar

### Server
- Linux-server (testad pa Raspberry Pi 4/5, arm64)
- Docker v24+ och Docker Compose v2+ installerat
- `git`, `make`, `curl` installerat

### Nätverkstjänster
- Ett domännamn (t.ex. `yourdomain.com`)
- Domänen hanteras av **Cloudflare** (används for DNS-challenge/SSL)
- Portarna **80** och **443** öppna och vidarebefordrade till servern i routern

### Cloudflare
1. Lägg till din domän i Cloudflare
2. Skapa ett **API-token** med behörighet: `Zone / DNS / Edit` for din domän
3. Spara token — du behöver det i `.env`

---

## Installation

### 1. Klona repot

```bash
git clone https://github.com/yourusername/docker2.git ~/docker2
cd ~/docker2
```

### 2. Kör setup-skriptet

```bash
bash setup.sh
```

Skriptet gör automatiskt:
- Kopierar alla `.env.example` → `.env` (om `.env` saknas)
- Skapar Docker-nätverk for varje stack
- Skapar datakatalogerna under `DATADIR`
- Sätter rätt filrättigheter

### 3. Fyll i .env-filerna

Start med den globala `.env` i rooten:

```bash
nano .env
```

Ändra dessa värden:

| Variabel | Beskrivning |
|----------|-------------|
| `PUID` / `PGID` | Din användar-ID (`id -u` / `id -g`) |
| `TZ` | Tidszon, t.ex. `Europe/Stockholm` |
| `DOMAIN` | Din domän, t.ex. `yourdomain.com` |
| `DOCKERDIR` | Sökväg till detta repo, t.ex. `/home/youruser/docker2` |
| `DATADIR` | Var container-data ska lagras, t.ex. `/home/youruser/dockdata` |
| `CF_API_EMAIL` | Din Cloudflare-e-post |
| `CF_DNS_API_TOKEN` | Ditt Cloudflare API-token |

Sedan fyller du i eventuella stack-specifika `.env`-filer:

```bash
nano traefik/.env        # (om du vill overrida)
nano smart-home/.env     # DATADIR etc.
nano nintendo_switch/.env # Aerofoil + Transmission-lösenord
nano claude_build/.env   # Appar med secrets
```

### 4. Uppdatera Traefik-config

Öppna `traefik/traefik.yml` och byt ut e-postadressen:

```yaml
certificatesResolvers:
  cloudflare:
    acme:
      email: your-cloudflare-email@example.com  # <- din email
```

### 5. Skapa acme.json

Traefik behöver en tom fil for SSL-certifikat:

```bash
touch traefik/acme.json
chmod 600 traefik/acme.json
```

### 6. Starta Traefik forst

Traefik måste vara igång innan andra stackar startar (annars misslyckas nätverkskopplingen).

```bash
make up-traefik
```

Vänta ~30 sekunder och kontrollera att certifikat hämtats:

```bash
docker logs traefik --tail 20
```

### 7. Starta övriga stackar

```bash
make up
```

Eller en stack i taget:

```bash
make up-smart-home
make up-music
make up-portainer
```

---

## Dagliga kommandon

```bash
make ps              # Status for alla containers
make logs-<stack>    # Loggar for en stack (ex: make logs-smart-home)
make restart-<stack> # Starta om en stack
make pull            # Hämta senaste images
make down            # Stoppa allt
make up              # Starta allt
make clean           # Rensa oanvända images och volumes
```

---

## Nätverksarkitektur

Varje stack har ett eget isolerat Docker-nätverk. Alla tjänster som ska nås via Traefik är även kopplade till det externa `traefik`-nätverket.

```
Internet
   |
[Router NAT :80/:443]
   |
[Traefik] ─── traefik-network ─── alla services med Traefik-labels
   |
   ├─ smart_home network  (HA ↔ Mosquitto ↔ Music Assistant ↔ Matter)
   ├─ nintendo_switch     (Prowlarr ↔ Flaresolverr, Aerofoil ↔ Transmission)
   ├─ music               (Navidrome ↔ Beets, Metube)
   ├─ torrents            (Deluge, isolerat)
   ├─ claude_build        (Egna appar)
   └─ networks            (NetAlertX, WatchYourLAN)
```

---

## Lägga till en ny tjänst

1. Skapa undermapp i rätt stack, t.ex. `smart-home/min-tjänst/`
2. Lägg till `docker-compose-min-tjänst.yml` i mappen
3. Inkludera den i stackens `docker-compose.yml` med `include:`
4. Lägg till Traefik-labels (mall nedan)
5. Kör `bash setup.sh` om nya nätverk/kataloger behövs

### Traefik-labels-mall

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.min-app-secure.rule=Host(`app.yourdomain.com`)"
  - "traefik.http.routers.min-app-secure.entrypoints=https"
  - "traefik.http.routers.min-app-secure.tls=true"
  - "traefik.http.routers.min-app-secure.tls.certresolver=cloudflare"
  - "traefik.http.services.min-app-service.loadbalancer.server.port=8080"
  - "traefik.http.routers.min-app-secure.middlewares=sslheader@docker"
```

---

## Home Assistant – specialfall

HA körs med `network_mode: host` och är alltså inte på Traefik-nätverket. Traefik når den via host-IP istället:

```yaml
labels:
  - "traefik.http.services.homeassistant-service.loadbalancer.server.url=http://192.168.0.X:8123"
```

Lägg till Traefik-subnätet i `configuration.yaml`:

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 172.16.0.0/12
    - 192.168.0.0/16
```

---

## Felsökning

### Certifikat hämtas inte
- Kontrollera att port 80/443 är öppna i routern
- Verifiera att `CF_DNS_API_TOKEN` har rätt behörighet i Cloudflare
- Kolla loggar: `docker logs traefik --tail 50`

### Container hittar inte nätverk
- Kör `bash setup.sh` igen — skapar saknade nätverk
- Kontrollera att nätverket är `external: true` i compose-filen

### acme.json-fel
```bash
chmod 600 traefik/acme.json
docker restart traefik
```

---

## Mappar som inte pushas till Git

| Mapp/fil | Anledning |
|----------|-----------|
| `**/.env` | Innehåller lösenord och API-nycklar |
| `traefik/acme.json` | SSL-certifikat (genereras automatiskt) |
| `docs-secrets/` | Personlig dokumentation |

---

## Krav – snabbsammanfattning

```
[ ] Linux-server (Raspberry Pi eller annan, arm64 eller amd64)
[ ] Docker + Docker Compose installerat
[ ] Domän registrerad och hanterad av Cloudflare
[ ] Cloudflare API-token skapat
[ ] Port 80 och 443 öppna i routern mot servern
[ ] .env filer ifyllda
[ ] traefik/acme.json skapad med chmod 600
```
