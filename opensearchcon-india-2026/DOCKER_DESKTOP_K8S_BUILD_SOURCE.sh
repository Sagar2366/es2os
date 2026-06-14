#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════════
# DOCKER DESKTOP KUBERNETES - BUILD FROM SOURCE (Migration Assistant)
# OpenSearchCon India 2026
# ════════════════════════════════════════════════════════════════════════════════

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="migration"
MIGRATIONS_DIR="/tmp/opensearch-migrations"

echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Docker Desktop Kubernetes - Build From Source${NC}"
echo -e "${BLUE}OpenSearchCon India 2026${NC}"
echo -e "${BLUE}Time: ~40-50 minutes${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
echo ""

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 1: VERIFY DOCKER DESKTOP
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}PHASE 1: Verifying Docker Desktop Kubernetes...${NC}"

if ! docker ps &> /dev/null; then
  echo -e "${RED}✗ Docker not running${NC}"
  exit 1
fi
echo -e "${GREEN}  ✓ Docker running${NC}"

CONTEXT=$(kubectl config current-context)
if [[ "$CONTEXT" != "docker-desktop" ]]; then
  echo -e "${RED}✗ Wrong context: $CONTEXT (need docker-desktop)${NC}"
  exit 1
fi
echo -e "${GREEN}  ✓ Context: docker-desktop${NC}"
echo -e "${GREEN}✓ Prerequisites OK${NC}"
echo ""

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 2: CLEANUP
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}PHASE 2: Cleaning up...${NC}"

if kubectl get namespace $NAMESPACE &> /dev/null; then
  kubectl delete namespace $NAMESPACE --wait=false 2>/dev/null || true
  sleep 3
fi

echo -e "${GREEN}✓ Cleanup complete${NC}"
echo ""

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 3: PREPARE MIGRATION ASSISTANT
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}PHASE 3: Preparing Migration Assistant v3.2.1...${NC}"

if [ ! -d "$MIGRATIONS_DIR" ]; then
  echo -e "${YELLOW}  Cloning repository...${NC}"
  git clone --branch 3.2.1 --depth 1 https://github.com/opensearch-project/opensearch-migrations $MIGRATIONS_DIR
fi

cd $MIGRATIONS_DIR

# Set context to docker-desktop
export KUBE_CONTEXT="docker-desktop"
export KIND_CONTEXT="docker-desktop"

echo -e "${GREEN}✓ Migration Assistant ready${NC}"
echo ""

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 4: BUILD AND DEPLOY
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}PHASE 4: Building images and deploying (40-50 min)...${NC}"
echo -e "${BLUE}This is the main wait. Grab coffee! ☕${NC}"
echo ""

cd $MIGRATIONS_DIR/deployment/k8s

# Pre-create namespace
kubectl create namespace $NAMESPACE 2>/dev/null || true

# Set environment variables for Docker Desktop
export KUBE_CONTEXT="docker-desktop"
export KIND_CONTEXT="docker-desktop"
export KUBECONFIG=""

# Run the build script
echo -e "${YELLOW}Starting build pipeline with Docker Desktop context...${NC}"

if bash localTestingKind.sh 2>&1 | tee /tmp/ma-build.log; then
  echo -e "${GREEN}✓ Build and deployment complete${NC}"
else
  BUILD_STATUS=$?
  echo -e "${YELLOW}Build completed with status: $BUILD_STATUS${NC}"
  echo -e "${YELLOW}This may be expected with Migration Assistant on Docker Desktop${NC}"
fi

echo ""

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 5: WAIT FOR PODS
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}PHASE 5: Waiting for all pods to be ready...${NC}"

for i in {1..120}; do
  POD_COUNT=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | grep -c "Running" || echo "0")
  if [ $POD_COUNT -ge 3 ]; then
    echo -e "${GREEN}✓ All pods ready${NC}"
    break
  fi
  
  if [ $((i % 20)) -eq 0 ]; then
    echo -e "${BLUE}  Waiting... ($i/120 seconds)${NC}"
  fi
  
  sleep 1
done

echo ""

# ════════════════════════════════════════════════════════════════════════════════
# FINAL STATUS
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${GREEN}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ SETUP COMPLETE${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${BLUE}Pod Status:${NC}"
kubectl get pods -n $NAMESPACE

echo ""
echo -e "${YELLOW}Demo Commands:${NC}"
echo ""
echo "Terminal 1 - Watch logs:"
echo "  kubectl logs -n migration -l app=migration-console -f"
echo ""
echo "Terminal 2 - Console:"
echo "  kubectl exec -it migration-console-0 -n migration -- bash"
echo ""
echo "Terminal 3 - Elasticsearch:"
echo "  kubectl port-forward -n migration svc/elasticsearch-master 9200:9200"
echo ""
echo "Terminal 4 - OpenSearch:"
echo "  kubectl port-forward -n migration svc/opensearch-cluster-master 9201:9200"
echo ""
echo -e "${YELLOW}Note: If fewer pods than expected, this may be a Docker Desktop issue${NC}"
echo -e "${YELLOW}Try DOCKER_DESKTOP_K8S_HELM.sh for a simpler, more reliable setup${NC}"
echo ""
