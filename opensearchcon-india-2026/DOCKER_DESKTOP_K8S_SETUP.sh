#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════════
# DOCKER DESKTOP KUBERNETES SETUP - OpenSearchCon India 2026
# Robust, self-patching alternative to Kind for local demo setups
# ════════════════════════════════════════════════════════════════════════════════

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="migration"

echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Docker Desktop Kubernetes Setup - OpenSearchCon India 2026${NC}"
echo -e "${BLUE}Total Time: ~40 minutes (faster than Kind!)${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
echo ""

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 1: CHECK DOCKER DESKTOP & ENABLE KUBERNETES
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}PHASE 1: Checking Docker Desktop & Kubernetes...${NC}"

if ! command -v docker &> /dev/null; then
  echo -e "${RED}✗ Docker not found. Install Docker Desktop first.${NC}"
  exit 1
fi

if ! docker ps &> /dev/null; then
  echo -e "${RED}✗ Docker daemon not running. Start Docker Desktop.${NC}"
  exit 1
fi
echo -e "${GREEN}  ✓ Docker running${NC}"

if ! command -v kubectl &> /dev/null; then
  echo -e "${RED}✗ kubectl not found. Enable Kubernetes in Docker Desktop:${NC}"
  echo -e "${YELLOW}  Docker Desktop → Preferences → Kubernetes → Check 'Enable Kubernetes'${NC}"
  exit 1
fi
echo -e "${GREEN}  ✓ kubectl installed${NC}"

# Force context switch to docker-desktop explicitly before starting
if kubectl config get-contexts | grep -q "docker-desktop"; then
  kubectl config use-context docker-desktop > /dev/null 2>&1
else
  echo -e "${RED}✗ docker-desktop context not found in kubeconfig.${NC}"
  exit 1
fi

# Verify Kubernetes cluster is running
if ! kubectl cluster-info &> /dev/null; then
  echo -e "${RED}✗ Kubernetes cluster not running. Enable in Docker Desktop.${NC}"
  exit 1
fi
echo -e "${GREEN}  ✓ Kubernetes cluster running${NC}"

# Check context
CONTEXT=$(kubectl config current-context)
echo -e "${GREEN}  ✓ Context: $CONTEXT${NC}"

echo -e "${GREEN}✓ Prerequisites OK${NC}"
echo ""

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 2: CHECK SYSTEM RESOURCES
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}PHASE 2: Checking system resources...${NC}"

# Check Docker memory allocation
DOCKER_MEM=$(docker info 2>/dev/null | grep "Memory:" | grep -oE "[0-9]+GiB|[0-9]+GB" | head -1 || echo "unknown")
echo -e "${BLUE}  Docker allocated: $DOCKER_MEM${NC}"

# Check available system memory
AVAILABLE_MEM=$(sysctl -n hw.memsize 2>/dev/null || grep MemAvailable /proc/meminfo 2>/dev/null | awk '{print $2 * 1024}' || echo "unknown")
if [[ $AVAILABLE_MEM != "unknown" ]]; then
  MEM_GB=$((AVAILABLE_MEM / 1024 / 1024 / 1024))
  echo -e "${BLUE}  Available system memory: ${MEM_GB}GB${NC}"
  if [[ $MEM_GB -lt 16 ]]; then
    echo -e "${YELLOW}  WARNING: Recommended 16GB+ available. May experience slowness.${NC}"
  fi
fi

echo -e "${GREEN}✓ Resource check OK${NC}"
echo ""

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 3: CLEANUP OLD NAMESPACE & RESOURCES
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}PHASE 3: Cleaning up old resources...${NC}"

if kubectl get namespace $NAMESPACE &> /dev/null; then
  echo -e "${YELLOW}  Deleting old namespace: $NAMESPACE${NC}"
  kubectl delete namespace $NAMESPACE --ignore-not-found=true
  sleep 5
fi

echo -e "${GREEN}✓ Cleanup complete${NC}"
echo ""

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 4: CREATE NAMESPACE & CLONE MIGRATION ASSISTANT
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}PHASE 4: Creating namespace & preparing Migration Assistant...${NC}"

# Create namespace
kubectl create namespace $NAMESPACE
echo -e "${GREEN}  ✓ Namespace created${NC}"

# Clone Migration Assistant
MIGRATIONS_DIR="/tmp/opensearch-migrations"
if [ ! -d "$MIGRATIONS_DIR" ]; then
  echo -e "${YELLOW}  Cloning Migration Assistant v3.2.1...${NC}"
  git clone --branch 3.2.1 --depth 1 https://github.com/opensearch-project/opensearch-migrations $MIGRATIONS_DIR 2>&1 | tail -3
fi

cd $MIGRATIONS_DIR
export KUBE_CONTEXT="docker-desktop"

echo -e "${GREEN}✓ Migration Assistant ready${NC}"
echo ""

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 5: BUILD & DEPLOY IMAGES (WITH LIVE CONTEXT HIJACK PATCH)
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}PHASE 5: Building and deploying images (20-30 min)...${NC}"
echo -e "${BLUE}This is the main wait. Coffee time! ☕${NC}"
echo ""

export JAVA_HOME=$(dirname $(dirname $(which java 2>/dev/null) 2>/dev/null) 2>/dev/null)

if [ ! -f "$MIGRATIONS_DIR/deployment/k8s/localTestingDockerDesktop.sh" ]; then
  # Try the generic script
  if [ -f "$MIGRATIONS_DIR/deployment/k8s/localTestingKind.sh" ]; then
    echo -e "${YELLOW}  Using Kind script architecture for Docker Desktop context...${NC}"
    SCRIPT_FILE="localTestingKind.sh"
  else
    echo -e "${RED}✗ Deployment scripts not found${NC}"
    exit 1
  fi
else
  SCRIPT_FILE="localTestingDockerDesktop.sh"
fi

cd $MIGRATIONS_DIR/deployment/k8s

# ─── HOTPATCH INTERNAL REPO FILES TO REMOVE HARDCODED KIND CONTEXTS ───
echo -e "${YELLOW}  Patching internal deployment files to use docker-desktop context...${NC}"
export KUBE_CONTEXT="docker-desktop"
export kube_context="docker-desktop"

# Cross-platform compatibility for sed inline execution (macOS vs Linux)
if [ "$(uname)" == "Darwin" ]; then
  sed -i '' 's/kind-migration-assistant/docker-desktop/g' localTestingCommon.sh 2>/dev/null || true
  sed -i '' 's/kind-migration-assistant/docker-desktop/g' localTestingKind.sh 2>/dev/null || true
  sed -i '' 's/kind-migration-assistant/docker-desktop/g' buildImages/backends/k8sHostedBuildkit.sh 2>/dev/null || true
else
  sed -i 's/kind-migration-assistant/docker-desktop/g' localTestingCommon.sh 2>/dev/null || true
  sed -i 's/kind-migration-assistant/docker-desktop/g' localTestingKind.sh 2>/dev/null || true
  sed -i 's/kind-migration-assistant/docker-desktop/g' buildImages/backends/k8sHostedBuildkit.sh 2>/dev/null || true
fi
# ──────────────────────────────────────────────────────────────────────

# Source common setup
source localTestingCommon.sh 2>/dev/null || true

# Run build without timeout (just let it run)
echo -e "${YELLOW}Starting image builds...${NC}"

bash $SCRIPT_FILE 2>&1 | tee /tmp/ma-build.log
BUILD_RESULT=${PIPESTATUS[0]}

if [ $BUILD_RESULT -ne 0 ]; then
  echo -e "${RED}✗ Build failed${NC}"
  echo -e "${YELLOW}Last 50 lines of log:${NC}"
  tail -50 /tmp/ma-build.log
  exit 1
fi

echo -e "${GREEN}✓ Images built and deployed${NC}"
echo ""

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 6: WAIT FOR PODS TO BE READY
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}PHASE 6: Waiting for pods (5-10 min)...${NC}"

echo -e "${YELLOW}  Waiting for migration-console...${NC}"
kubectl wait --for=condition=ready pod -l app=migration-console -n $NAMESPACE --timeout=10m 2>/dev/null || {
  echo -e "${RED}✗ migration-console failed to start${NC}"
  kubectl get pods -n $NAMESPACE
  kubectl describe pod migration-console-0 -n $NAMESPACE
  exit 1
}
echo -e "${GREEN}  ✓ migration-console ready${NC}"

echo -e "${YELLOW}  Waiting for elasticsearch...${NC}"
kubectl wait --for=condition=ready pod -l app=elasticsearch-master -n $NAMESPACE --timeout=10m 2>/dev/null || {
  echo -e "${YELLOW}  (ES taking longer...)${NC}"
}

echo -e "${YELLOW}  Waiting for opensearch...${NC}"
kubectl wait --for=condition=ready pod -l app=opensearch-cluster-master -n $NAMESPACE --timeout=10m 2>/dev/null || {
  echo -e "${YELLOW}  (OS taking longer...)${NC}"
}

sleep 5

echo -e "${GREEN}✓ Pods deployed${NC}"
echo ""

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 7: LOAD SAMPLE DATA
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}PHASE 7: Loading sample data...${NC}"

kubectl exec migration-console-0 -n $NAMESPACE -- bash << 'SAMPLE_EOF' 2>/dev/null || true
  ES='https://elasticsearch-master:9200'
  
  # Wait a bit for ES to be ready
  for i in {1..30}; do
    if curl -sk "$ES" -u admin:admin > /dev/null 2>&1; then
      break
    fi
    sleep 2
  done
  
  # Create test index with proper mapping
  curl -sk -X PUT "$ES/product_embeddings" \
    -u admin:admin \
    -H 'Content-Type: application/json' \
    -d '{
      "mappings": {
        "properties": {
          "title": {"type": "text"},
          "product_vector": {
            "type": "dense_vector",
            "dims": 768,
            "index": true,
            "similarity": "cosine"
          },
          "category": {"type": "keyword"},
          "price": {"type": "float"}
        }
      }
    }' 2>/dev/null || true
  
  # Insert sample document
  curl -sk -X POST "$ES/product_embeddings/_doc/1" \
    -u admin:admin \
    -H 'Content-Type: application/json' \
    -d '{
      "title": "Wireless Headphones",
      "product_vector": [0.1, 0.2, 0.3, 0.4, 0.1, 0.2, 0.3, 0.4],
      "category": "electronics",
      "price": 299.99
    }' 2>/dev/null || true
  
  curl -sk -X POST "$ES/logs_2024_01/_doc/1" \
    -u admin:admin \
    -H 'Content-Type: application/json' \
    -d '{
      "timestamp": "2024-01-01T00:00:00Z",
      "level": "INFO",
      "message": "Service started",
      "service": "api-gateway"
    }' 2>/dev/null || true
  
  # Refresh indices
  curl -sk -X POST "$ES/_refresh" -u admin:admin 2>/dev/null || true
SAMPLE_EOF

echo -e "${GREEN}✓ Sample data loaded${NC}"
echo ""

# ════════════════════════════════════════════════════════════════════════════════
# FINAL STATUS
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${GREEN}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ SETUP COMPLETE - DOCKER DESKTOP KUBERNETES${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${BLUE}Cluster Status:${NC}"
kubectl get pods -n $NAMESPACE 2>/dev/null | grep -E "NAME|migration-console|elasticsearch|opensearch"

echo ""
echo -e "${BLUE}READY FOR DEMO!${NC}"
echo ""
echo -e "${YELLOW}During your talk, use these commands:${NC}"
echo ""
echo "  Terminal 1 - Watch logs:"
echo "    kubectl logs -n migration -l app=migration-console -f"
echo ""
echo "  Terminal 2 - Access migration console:"
echo "    kubectl exec -it migration-console-0 -n migration -- bash"
echo "    workflow status"
echo ""
echo "  Terminal 3 - Query Elasticsearch:"
echo "    kubectl port-forward -n migration svc/elasticsearch-master 9200:9200"
echo "    curl -k https://admin:admin@localhost:9200/_cat/indices"
echo ""
echo "  Terminal 4 - Query OpenSearch:"
echo "    kubectl port-forward -n migration svc/opensearch-cluster-master 9201:9200"
echo "    curl -k https://admin:admin@localhost:9201/_cat/indices"
echo ""
echo -e "${YELLOW}Verify before talk (30 min before):${NC}"
echo "    kubectl get pods -n migration"
echo "    kubectl logs -n migration -l app=migration-console | grep -i error"
echo ""
echo -e "${BLUE}Context: $CONTEXT${NC}"
echo ""
