#!/bin/bash
# =============================================================================
# docker2/setup.sh – Bootstrap-skript för hela servern
# Kör detta efter en färsk git clone: bash setup.sh
# Idempotent – säkert att köra flera gånger
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATADIR="${DATADIR:-/home/$(whoami)/dockdata}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[OK]${NC}  $*"; }
warn() { echo -e "${YELLOW}[--]${NC}  $*"; }
err()  { echo -e "${RED}[!!]${NC}  $*"; }

echo ""
echo "========================================"
echo "  docker2 – Server Bootstrap"
echo "========================================"
echo ""

# -----------------------------------------------------------------------------
# 1. Miljöfiler – kopiera .env.example → .env om .env saknas
# -----------------------------------------------------------------------------
echo ">>> Miljöfiler"
find "$SCRIPT_DIR" -name ".env.example" | while read -r example; do
  envfile="${example%.example}"
  if [ ! -f "$envfile" ]; then
    cp "$example" "$envfile"
    warn ".env skapad från exempel: ${envfile#"$SCRIPT_DIR"/} – FYLL I VÄRDENA"
  else
    log ".env finns redan: ${envfile#"$SCRIPT_DIR"/}"
  fi
done

# -----------------------------------------------------------------------------
# 2. Filrättigheter
# -----------------------------------------------------------------------------
echo ""
echo ">>> Filrättigheter"

ACME="$SCRIPT_DIR/traefik/acme.json"
if [ -f "$ACME" ]; then
  chmod 600 "$ACME"
  log "chmod 600 traefik/acme.json"
fi

ENTRYPOINT="$SCRIPT_DIR/sftp/entrypoint.sh"
if [ -f "$ENTRYPOINT" ]; then
  chmod +x "$ENTRYPOINT"
  log "chmod +x sftp/entrypoint.sh"
fi

# Gör alla entrypoint.sh körbara automatiskt
find "$SCRIPT_DIR" -name "entrypoint.sh" -exec chmod +x {} \; -exec log "chmod +x {}" \;

# -----------------------------------------------------------------------------
# 3. Docker-nätverk – skapas automatiskt baserat på projektmappar
# -----------------------------------------------------------------------------
echo ""
echo ">>> Docker-nätverk"

# Alltid skapa traefik-nätverket
create_network() {
  local name="$1"
  local driver="${2:-bridge}"
  if docker network inspect "$name" &>/dev/null; then
    log "Nätverk finns redan: $name"
  else
    docker network create --driver "$driver" "$name"
    log "Nätverk skapat: $name"
  fi
}

# Traefik (huvud)
create_network traefik

# Automatisk: skapa nätverk för varje projektmapp (om det finns en docker-compose.yml)
for dir in "$SCRIPT_DIR"/*/; do
  name="$(basename "$dir")"
  # Hoppa över mappar utan compose-fil
  [ -f "${dir}docker-compose.yml" ] || continue
  # Byt bindestreck mot understreck i nätverksnamn
  netname="${name//-/_}"
  create_network "$netname"
done

# -----------------------------------------------------------------------------
# 4. Dockdata-kataloger – skapas automatiskt baserat på tjänstenamn
# -----------------------------------------------------------------------------
echo ""
echo ">>> Datakatalog: $DATADIR"

SERVICES=(
  traefik
  portainer
  sftp
  homer
  aerofoil
  transmission
  prowlarr
  flaresolverr
  homeassistant
  musicassistant
  matterserver
  mosquitto
  wyoming-faster-whisper
  wyoming-piper
  navidrome
  beets
  metube
  deluge
  lidarr
  booklore
  netalertx
  watchyourlan
  dashboard
  elitetube
  forsaljning
  tidsrapport
)

for svc in "${SERVICES[@]}"; do
  dir="$DATADIR/$svc"
  if [ ! -d "$dir" ]; then
    mkdir -p "$dir"
    log "Skapade: $dir"
  else
    log "Finns redan: $dir"
  fi
done

# -----------------------------------------------------------------------------
# 5. Loggar-katalog för traefik
# -----------------------------------------------------------------------------
echo ""
echo ">>> Loggar"
mkdir -p "$SCRIPT_DIR/logs/traefik"
log "Skapade: $SCRIPT_DIR/logs/traefik"

# -----------------------------------------------------------------------------
# 6. Klar
# -----------------------------------------------------------------------------
echo ""
echo "========================================"
echo "  Setup klar!"
echo "========================================"
echo ""
echo "Nästa steg:"
echo "  1. Fyll i .env-filer som skapades med [--]"
echo "  2. Starta traefik först:  cd traefik && docker compose up -d"
echo "  3. Starta övriga stackar: make up"
echo ""
