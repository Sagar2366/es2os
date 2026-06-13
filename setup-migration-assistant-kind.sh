#!/bin/bash
# OpenSearchCon India 2026 — Migration Assistant on Kind (Local K8s)
# This sets up the REAL Migration Assistant locally using Kind/Minikube
#
# Prerequisites:
#   - JDK 11-17
#   - Docker (with at least 8 vCPU + 12GB RAM allocated)
#   - minikube, kubectl, helm 3
#
# Time: ~30-45 min first run (builds images from source)
# After first run: ~5 min (images cached)

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Migration Assistant — Kind/Minikube Local Setup             ║"
echo "║  OpenSearchCon India 2026 Demo                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# ─── Prerequisites Check ───────────────────────────────────────────────

echo "━━━ Prerequisites ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

check() {
  if command -v "$1" &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} $1 found"
  else
    echo -e "  ${RED}✗${NC} $1 NOT FOUND — install it first"
    MISSING=true
  fi
}

MISSING=false
check docker
check minikube
check kubectl
check helm
check java

# Check Java version
if command -v java &> /dev/null; then
  JAVA_VER=$(java -version 2>&1 | head -1 | grep -oE '[0-9]+' | head -1)
  if [ "$JAVA_VER" -ge 11 ] && [ "$JAVA_VER" -le 17 ]; then
    echo -e "  ${GREEN}✓${NC} Java version $JAVA_VER (required: 11-17)"
  else
    echo -e "  ${RED}✗${NC} Java version $JAVA_VER — need 11-17"
    MISSING=true
  fi
fi

# Check Docker memory
DOCKER_MEM=$(docker info 2>/dev/null | grep "Total Memory" | grep -oE '[0-9]+\.[0-9]+' | head -1)
if [ -n "$DOCKER_MEM" ]; then
  MEM_INT=$(echo "$DOCKER_MEM" | cut -d. -f1)
  if [ "$MEM_INT" -ge 12 ]; then
    echo -e "  ${GREEN}✓${NC} Docker memory: ${DOCKER_MEM}GB (need ≥12GB)"
  else
    echo -e "  ${YELLOW}⚠${NC} Docker memory: ${DOCKER_MEM}GB — recommend ≥12GB"
    echo "    Increase in Docker Desktop → Settings → Resources"
  fi
fi

if [ "$MISSING" = true ]; then
  echo ""
  echo -e "${RED}Missing prerequisites. Install them and re-run.${NC}"
  exit 1
fi

echo ""

# ─── Clone Migration Assistant ─────────────────────────────────────────

RELEASE_TAG="3.3.1"
CLONE_DIR="$HOME/Desktop/opensearch-migrations"

echo "━━━ Clone Migration Assistant (v${RELEASE_TAG}) ━━━━━━━━━━━━━━━━━"

if [ -d "$CLONE_DIR" ]; then
  echo -e "  ${GREEN}✓${NC} Already cloned at $CLONE_DIR"
  cd "$CLONE_DIR"
  # Verify we're on the right tag
  CURRENT_TAG=$(git describe --tags 2>/dev/null || echo "unknown")
  echo "    Current: $CURRENT_TAG"
else
  echo "  Cloning opensearch-migrations (tag: $RELEASE_TAG)..."
  git clone --branch "$RELEASE_TAG" https://github.com/opensearch-project/opensearch-migrations.git "$CLONE_DIR"
  cd "$CLONE_DIR"
  echo -e "  ${GREEN}✓${NC} Cloned to $CLONE_DIR"
fi

echo ""

# ─── Run Local Testing Setup ──────────────────────────────────────────

echo "━━━ Deploy Migration Assistant to Minikube ━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "  ${YELLOW}⚠  This takes 30-45 min on first run (building images)${NC}"
echo "     Subsequent runs are faster (~5 min, images cached)"
echo ""
echo "  Running: ./deployment/k8s/localTesting.sh"
echo ""

cd deployment/k8s

if [ -f "localTesting.sh" ]; then
  chmod +x localTesting.sh
  ./localTesting.sh
else
  echo -e "  ${RED}✗${NC} localTesting.sh not found at $(pwd)"
  echo "    Try running manually:"
  echo "    cd $CLONE_DIR/deployment/k8s"
  echo "    ./localTesting.sh"
  exit 1
fi

echo ""

# ─── Verify Deployment ─────────────────────────────────────────────────

echo "━━━ Verify Deployment ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "  Pods in 'ma' namespace:"
kubectl get pods -n ma 2>/dev/null || echo -e "  ${RED}✗${NC} kubectl failed — is minikube running?"

echo ""

# ─── Access Console ────────────────────────────────────────────────────

echo "━━━ Migration Console Access ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  To access the Migration Console:"
echo ""
echo "    kubectl exec -it migration-console-0 -n ma -- /bin/bash"
echo ""
echo "  Inside the console, run:"
echo ""
echo "    console --version"
echo "    workflow configure sample --load"
echo "    console clusters connection-check"
echo ""
echo "  To run a migration workflow:"
echo ""
echo "    # 1. Check connectivity"
echo "    console clusters connection-check"
echo ""
echo "    # 2. Migrate metadata (mappings, templates, aliases)"
echo "    console metadata migrate"
echo ""
echo "    # 3. Start backfill (RFS — Reindex from Snapshot)"
echo "    console backfill start"
echo "    console backfill status"
echo ""
echo "    # 4. Check target cluster"
echo "    console clusters cat-indices --target"
echo ""

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  ✅ Migration Assistant is ready!                            ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Demo commands for the talk:"
echo ""
echo "  # Show pods running"
echo "  kubectl get pods -n ma"
echo ""
echo "  # Enter console"
echo "  kubectl exec -it migration-console-0 -n ma -- /bin/bash"
echo ""
echo "  # Run metadata migration"
echo "  console metadata migrate"
echo ""
echo "  # Start and monitor backfill"
echo "  console backfill start"
echo "  console backfill status"
echo ""
echo "  # Verify on target"
echo "  console clusters cat-indices --target"
echo ""
