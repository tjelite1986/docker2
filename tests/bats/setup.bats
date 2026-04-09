#!/usr/bin/env bats
# =============================================================================
# Tests for setup.sh
#
# Requires BATS: https://github.com/bats-core/bats-core
#   Install:  sudo apt install bats   OR   brew install bats-core
#   Run:      make test   OR   bats tests/bats/setup.bats
# =============================================================================

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

# Runs before each test – builds an isolated temp environment
setup() {
  TEST_DIR=$(mktemp -d)

  # Copy setup.sh so SCRIPT_DIR resolves to TEST_DIR (not the real repo)
  cp "$REPO_ROOT/setup.sh" "$TEST_DIR/"

  # Minimal .env.example files
  echo "KEY=placeholder" > "$TEST_DIR/.env.example"
  mkdir -p "$TEST_DIR/music"
  touch "$TEST_DIR/music/docker-compose.yml"
  echo "MUSIC_KEY=placeholder" > "$TEST_DIR/music/.env.example"

  # Mock docker so no real Docker calls are made during tests
  # MOCK_NET_EXISTS controls whether "docker network inspect" succeeds (0) or
  # fails (1, the default, meaning "network does not exist yet").
  mkdir -p "$TEST_DIR/bin"
  cat > "$TEST_DIR/bin/docker" <<'EOF'
#!/bin/bash
case "$1 $2" in
  "network inspect") exit "${MOCK_NET_EXISTS:-1}" ;;
  "network create")  exit 0 ;;
esac
exit 0
EOF
  chmod +x "$TEST_DIR/bin/docker"

  export PATH="$TEST_DIR/bin:$PATH"
  export DATADIR="$TEST_DIR/dockdata"
}

# Runs after each test – cleans up temp files
teardown() {
  rm -rf "$TEST_DIR"
}

# =============================================================================
# .env file management
# =============================================================================

@test ".env is created from .env.example when .env is missing" {
  run bash "$TEST_DIR/setup.sh"
  [ "$status" -eq 0 ]
  [ -f "$TEST_DIR/.env" ]
}

@test "new .env contains the content from .env.example" {
  run bash "$TEST_DIR/setup.sh"
  grep -q "KEY=placeholder" "$TEST_DIR/.env"
}

@test "existing .env is not overwritten" {
  echo "ORIGINAL=keep-me" > "$TEST_DIR/.env"
  run bash "$TEST_DIR/setup.sh"
  grep -q "ORIGINAL=keep-me" "$TEST_DIR/.env"
}

@test "stack .env is created from stack .env.example when missing" {
  run bash "$TEST_DIR/setup.sh"
  [ -f "$TEST_DIR/music/.env" ]
}

@test "stack .env is not overwritten when it already exists" {
  echo "STACK_ORIGINAL=keep-me" > "$TEST_DIR/music/.env"
  run bash "$TEST_DIR/setup.sh"
  grep -q "STACK_ORIGINAL=keep-me" "$TEST_DIR/music/.env"
}

# =============================================================================
# Data directory creation
# =============================================================================

@test "creates data directories for core services" {
  run bash "$TEST_DIR/setup.sh"
  [ "$status" -eq 0 ]
  [ -d "$DATADIR/traefik" ]
  [ -d "$DATADIR/portainer" ]
  [ -d "$DATADIR/navidrome" ]
}

@test "creates data directories for all 26 services" {
  run bash "$TEST_DIR/setup.sh"
  for svc in traefik portainer sftp homer aerofoil transmission prowlarr \
             flaresolverr homeassistant musicassistant matterserver mosquitto \
             wyoming-faster-whisper wyoming-piper navidrome beets metube \
             deluge lidarr booklore netalertx watchyourlan dashboard \
             elitetube forsaljning tidsrapport; do
    [ -d "$DATADIR/$svc" ] || {
      echo "Missing: $DATADIR/$svc"
      return 1
    }
  done
}

@test "creates logs/traefik directory" {
  run bash "$TEST_DIR/setup.sh"
  [ -d "$TEST_DIR/logs/traefik" ]
}

# =============================================================================
# Idempotency
# =============================================================================

@test "running setup.sh twice does not fail" {
  run bash "$TEST_DIR/setup.sh"
  [ "$status" -eq 0 ]
  run bash "$TEST_DIR/setup.sh"
  [ "$status" -eq 0 ]
}

@test "running twice does not duplicate .env content" {
  run bash "$TEST_DIR/setup.sh"
  run bash "$TEST_DIR/setup.sh"
  count=$(grep -c "KEY=placeholder" "$TEST_DIR/.env")
  [ "$count" -eq 1 ]
}

# =============================================================================
# File permissions
# =============================================================================

@test "sets chmod 600 on traefik/acme.json when it exists" {
  mkdir -p "$TEST_DIR/traefik"
  touch "$TEST_DIR/traefik/acme.json"
  chmod 644 "$TEST_DIR/traefik/acme.json"
  run bash "$TEST_DIR/setup.sh"
  perms=$(stat -c "%a" "$TEST_DIR/traefik/acme.json")
  [ "$perms" = "600" ]
}

@test "makes entrypoint.sh files executable" {
  mkdir -p "$TEST_DIR/myservice"
  touch "$TEST_DIR/myservice/entrypoint.sh"
  chmod 644 "$TEST_DIR/myservice/entrypoint.sh"
  run bash "$TEST_DIR/setup.sh"
  [ -x "$TEST_DIR/myservice/entrypoint.sh" ]
}

@test "does not fail when traefik/acme.json does not exist" {
  run bash "$TEST_DIR/setup.sh"
  [ "$status" -eq 0 ]
}

# =============================================================================
# Docker network creation
# =============================================================================

@test "exits successfully when networks do not exist yet" {
  export MOCK_NET_EXISTS=1
  run bash "$TEST_DIR/setup.sh"
  [ "$status" -eq 0 ]
}

@test "exits successfully when networks already exist" {
  export MOCK_NET_EXISTS=0
  run bash "$TEST_DIR/setup.sh"
  [ "$status" -eq 0 ]
}
