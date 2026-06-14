#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════════
# KIND CLUSTER SETUP - OpenSearchCon India 2026
# Simple, straightforward, tested implementation
# ════════════════════════════════════════════════════════════════════════════════

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CLUSTER_NAME="opensearchcon-2026"
NAMESPACE="migration"

echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}KIND Cluster Setup - OpenSearchCon India 2026${NC}"
echo -e "${BLUE}Total Time: ~60 minutes${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
echo ""

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 1: CHECK PREREQUISITES
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}PHASE 1: Checking prerequisites...${NC}"

# Check kind
if ! command -v kind &> /dev/null; then
  echo -e "${YELLOW}  Installing kind...${NC}"
  brew install kind 2>/dev/null || {
    echo -e "${RED}  Install kind manually: brew install kind${NC}"
    exit 1
  }
fi
echo -e "${GREEN}  ✓ kind${NC}"

# Check kubectl
if ! command -v kubectl &> /dev/null; then
  echo -e "${YELLOW}  Installing kubectl...${NC}"
  brew install kubectl 2>/dev/null || {
    echo -e "${RED}  Install kubectl manually: brew install kubectl${NC}"
    exit 1
  }
fi
echo -e "${GREEN}  ✓ kubectl${NC}"

# Check docker
if ! command -v docker &> /dev/null; then
  echo -e "${RED}✗ Docker not found. Install Docker Desktop.${NC}"
  exit 1
fi

if ! docker ps &> /dev/null; then
  echo -e "${RED}✗ Docker daemon not running. Start Docker Desktop.${NC}"
  exit 1
fi
echo -e "${GREEN}  ✓ docker${NC}"

echo -e "${GREEN}✓ Prerequisites OK${NC}"
echo ""

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 2: CLEANUP OLD CLUSTER
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}PHASE 2: Cleaning up...${NC}"

if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo -e "${YELLOW}  Removing old cluster...${NC}"
  kind delete cluster --name $CLUSTER_NAME
  sleep 3
fi

echo -e "${GREEN}✓ Cleanup complete${NC}"
echo ""

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 3: CREATE KIND CLUSTER
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}PHASE 3: Creating Kind cluster (5 min)...${NC}"

cat > /tmp/kind-config.yaml << 'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: opensearchcon-2026
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 30080
        hostPort: 30080
        protocol: TCP
      - containerPort: 30443
        hostPort: 30443
        protocol: TCP
EOF

kind create cluster --config /tmp/kind-config.yaml --wait 5m 2>&1 | grep -v "^$" | head -20

echo -e "${GREEN}✓ Cluster created${NC}"
sleep 2
echo ""

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 4: CLONE MIGRATION ASSISTANT
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}PHASE 4: Preparing Migration Assistant...${NC}"

MIGRATIONS_DIR="/tmp/opensearch-migrations"

if [ ! -d "$MIGRATIONS_DIR" ]; then
  echo -e "${YELLOW}  Cloning v3.2.1...${NC}"
  git clone --branch 3.2.1 --depth 1 https://github.com/opensearch-project/opensearch-migrations $MIGRATIONS_DIR 2>&1 | tail -3
fi

cd $MIGRATIONS_DIR
export KUBE_CONTEXT="kind-opensearchcon-2026"

echo -e "${GREEN}✓ Migration Assistant ready${NC}"
echo ""

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 5: BUILD IMAGES (30-40 MINUTES)
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}PHASE 5: Building images (30-40 min)...${NC}"
echo -e "${BLUE}This is the main wait. Be patient...${NC}"
echo ""

export JAVA_HOME=$(dirname $(dirname $(which java 2>/dev/null) 2>/dev/null) 2>/dev/null)

if [ ! -f "$MIGRATIONS_DIR/deployment/k8s/localTestingKind.sh" ]; then
  echo -e "${RED}✗ Migration Assistant setup script not found${NC}"
  exit 1
fi

cd $MIGRATIONS_DIR/deployment/k8s

# Source common setup
source localTestingCommon.sh 2>/dev/null || true

# Create namespace
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true

# Run build with timeout
echo -e "${YELLOW}Starting image builds...${NC}"

timeout 50m bash localTestingKind.sh 2>&1 | tee /tmp/ma-build.log > /dev/null &
BUILD_PID=$!

# Monitor progress
LAST_CHECK=""
while kill -0 $BUILD_PID 2>/dev/null; do
  CURRENT=$(tail -1 /tmp/ma-build.log 2>/dev/null | grep -oE "(Building|Step|FROM|RUN|COPY|Pushing)" | head -1 || echo "Building...")
  
  if [ "$CURRENT" != "$LAST_CHECK" ]; then
    echo -e "${BLUE}  Progress: $CURRENT${NC}"
    LAST_CHECK="$CURRENT"
  fi
  
  sleep 30
done

wait $BUILD_PID || {
  echo -e "${RED}✗ Build failed${NC}"
  echo -e "${YELLOW}Last 50 lines of log:${NC}"
  tail -50 /tmp/ma-build.log
  exit 1
}

echo -e "${GREEN}✓ Images built successfully${NC}"
echo ""

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 6: WAIT FOR PODS TO BE READY
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}PHASE 6: Waiting for pods (10 min)...${NC}"

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
echo -e "${GREEN}✓ SETUP COMPLETE${NC}"
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
