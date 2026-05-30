#!/usr/bin/env bash
# =============================================================================
# deploy.sh — Outbound AI Caller self-hosted setup
# Run this once on the target server after copying the bundle.
# Requires: Docker 24+ with the Compose plugin (docker compose)
# =============================================================================
set -e

BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_TAR="$BUNDLE_DIR/outbound-caller.tar"
COMPOSE_FILE="$BUNDLE_DIR/docker-compose.prod.yml"
ENV_EXAMPLE="$BUNDLE_DIR/.env.example"
ENV_FILE="$BUNDLE_DIR/.env"

# ── Colour helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; exit 1; }

echo ""
echo "========================================"
echo "  Outbound AI Caller — Deploy Script"
echo "========================================"
echo ""

# ── 1. Check Docker ───────────────────────────────────────────────────────────
command -v docker >/dev/null 2>&1 || error "Docker is not installed. Install it from https://docs.docker.com/engine/install/"
docker compose version >/dev/null 2>&1  || error "'docker compose' plugin not found. Update Docker to 24+."
info "Docker $(docker --version | awk '{print $3}' | tr -d ',')"

# ── 2. Load image ─────────────────────────────────────────────────────────────
if docker image inspect outbound-caller:latest >/dev/null 2>&1; then
  warn "Image 'outbound-caller:latest' already loaded — skipping load."
else
  [ -f "$IMAGE_TAR" ] || error "Image file not found: $IMAGE_TAR"
  info "Loading Docker image (this may take a minute)..."
  docker load -i "$IMAGE_TAR"
  info "Image loaded."
fi

# ── 3. Create .env if missing ─────────────────────────────────────────────────
if [ ! -f "$ENV_FILE" ]; then
  cp "$ENV_EXAMPLE" "$ENV_FILE"
  warn ".env created from .env.example — you MUST fill in your credentials before starting."
  warn "Edit the file now:  nano $ENV_FILE"
  echo ""
  read -rp "Press ENTER after saving .env to continue, or Ctrl-C to exit and edit first: "
else
  info ".env already exists — using existing file."
fi

# ── 4. Validate required keys ─────────────────────────────────────────────────
REQUIRED=(LIVEKIT_URL LIVEKIT_API_KEY LIVEKIT_API_SECRET GOOGLE_API_KEY SUPABASE_URL SUPABASE_KEY SUPABASE_SERVICE_KEY)
MISSING=()
for key in "${REQUIRED[@]}"; do
  val=$(grep -E "^${key}=" "$ENV_FILE" | cut -d= -f2-)
  if [[ -z "$val" || "$val" == "your_"* || "$val" == "https://your-"* || "$val" == "wss://your-"* ]]; then
    MISSING+=("$key")
  fi
done
if [ ${#MISSING[@]} -gt 0 ]; then
  error "The following required .env variables are not set: ${MISSING[*]}"
fi
info "All required .env keys are present."

# ── 5. Start services ─────────────────────────────────────────────────────────
info "Starting containers..."
docker compose -f "$COMPOSE_FILE" up -d

echo ""
info "Deployment complete!"
echo ""
echo "  Dashboard:  http://$(hostname -I | awk '{print $1}'):8000"
echo ""
echo "  Useful commands:"
echo "    docker compose -f $COMPOSE_FILE logs -f          # live logs"
echo "    docker compose -f $COMPOSE_FILE ps               # status"
echo "    docker compose -f $COMPOSE_FILE down             # stop"
echo "    docker compose -f $COMPOSE_FILE pull             # pull updates"
echo ""
