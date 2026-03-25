#!/bin/bash
# Återställer demo-databasen och seedar om den med testdata.
# Körs normalt via cron varje natt kl 03:00.

set -e

CONTAINER="tidsrapport-demo"
DB_PATH="/app/data/tidsrapport.db"

echo "[$(date)] Startar återställning av demo-databas..."

# Ta bort befintlig databas
docker exec "$CONTAINER" rm -f "$DB_PATH"
echo "[$(date)] Databas borttagen."

# Seed med grunddata
docker exec "$CONTAINER" npx tsx scripts/seed.ts
echo "[$(date)] Seed klar."

# Kör alla migrationer i ordning
for v in 2 3 4 5 6 7 8 9 10 11 12; do
  SCRIPT="scripts/migrate-v${v}.ts"
  if docker exec "$CONTAINER" test -f "$SCRIPT" 2>/dev/null; then
    docker exec "$CONTAINER" npx tsx "$SCRIPT" "$DB_PATH"
    echo "[$(date)] Migration v${v} klar."
  fi
done

echo "[$(date)] Demo-databasen aterstaälld."
