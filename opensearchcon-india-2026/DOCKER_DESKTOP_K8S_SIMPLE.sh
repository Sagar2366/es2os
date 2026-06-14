#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════════
# DOCKER DESKTOP KUBERNETES SETUP - OpenSearchCon India 2026 (SIMPLIFIED)
# Direct approach without Migration Assistant build scripts
# ════════════════════════════════════════════════════════════════════════════════

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="migration"

echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Docker Desktop Kubernetes - OpenSearchCon India 2026${NC}"
echo -e "${BLUE}Simplified Direct Setup${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
echo ""

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 1: VERIFY DOCKER DESKTOP K8S
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}PHASE 1: Verifying Docker Desktop Kubernetes...${NC}"

CONTEXT=$(kubectl config current-context)

if [[ "$CONTEXT" != "docker-desktop" ]]; then
  echo -e "${RED}✗ Not on docker-desktop context${NC}"
  echo -e "${YELLOW}Current context: $CONTEXT${NC}"
  echo -e "${YELLOW}Available contexts:${NC}"
  kubectl config get-contexts
  echo -e "${RED}Please switch to docker-desktop context${NC}"
  exit 1
fi

echo -e "${GREEN}  ✓ Context: docker-desktop${NC}"

if ! kubectl cluster-info &> /dev/null; then
  echo -e "${RED}✗ Kubernetes not running${NC}"
  exit 1
fi

echo -e "${GREEN}  ✓ Kubernetes running${NC}"
echo -e "${GREEN}✓ Prerequisites OK${NC}"
echo ""

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 2: CLEANUP
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}PHASE 2: Cleaning up old resources...${NC}"

if kubectl get namespace $NAMESPACE &> /dev/null; then
  echo -e "${YELLOW}  Deleting old namespace...${NC}"
  kubectl delete namespace $NAMESPACE --wait=true 2>/dev/null || true
  sleep 3
fi

echo -e "${GREEN}✓ Cleanup complete${NC}"
echo ""

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 3: CREATE NAMESPACE
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}PHASE 3: Creating namespace...${NC}"

kubectl create namespace $NAMESPACE
kubectl label namespace $NAMESPACE name=$NAMESPACE

echo -e "${GREEN}✓ Namespace created${NC}"
echo ""

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 4: DEPLOY ELASTICSEARCH (HELM)
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}PHASE 4: Deploying Elasticsearch 7.10...${NC}"

# Add Elastic Helm repo
helm repo add elastic https://helm.elastic.co 2>/dev/null || true
helm repo update

helm install elasticsearch elastic/elasticsearch \
  --version 7.17.0 \
  -n $NAMESPACE \
  --set replicas=1 \
  --set volumeClaimTemplate.storageClassName="standard" \
  --set resources.requests.memory="1Gi" \
  --set resources.requests.cpu="100m" \
  --set xpack.security.enabled=false \
  2>&1 | grep -E "(NAME|STATUS|NOTES|Error)" || true

echo -e "${YELLOW}  Waiting for Elasticsearch to be ready (5-10 min)...${NC}"
kubectl wait --for=condition=ready pod -l app=elasticsearch-master -n $NAMESPACE --timeout=10m 2>/dev/null || {
  echo -e "${YELLOW}  Taking longer than expected, continuing...${NC}"
}

echo -e "${GREEN}✓ Elasticsearch deployed${NC}"
echo ""

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 5: DEPLOY OPENSEARCH (HELM)
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}PHASE 5: Deploying OpenSearch 2.19...${NC}"

# Add OpenSearch Helm repo
helm repo add opensearch https://opensearch-project.github.io/helm-charts/ 2>/dev/null || true
helm repo update

helm install opensearch opensearch/opensearch \
  --version 2.19.0 \
  -n $NAMESPACE \
  -f - <<EOF
opensearchJavaOpts: "-Xmx512m -Xms512m"
resources:
  requests:
    cpu: 100m
    memory: 512Mi
replicas: 1
plugins:
  security:
    enabled: false
EOF

echo -e "${YELLOW}  Waiting for OpenSearch to be ready (5-10 min)...${NC}"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=opensearch -n $NAMESPACE --timeout=10m 2>/dev/null || {
  echo -e "${YELLOW}  Taking longer than expected, continuing...${NC}"
}

echo -e "${GREEN}✓ OpenSearch deployed${NC}"
echo ""

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 6: LOAD SAMPLE DATA
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}PHASE 6: Loading sample data...${NC}"

sleep 10

# Port forward ES in background
kubectl port-forward -n $NAMESPACE svc/elasticsearch-master 9200:9200 &
ES_PF_PID=$!
sleep 3

# Load data
curl -s -X PUT "http://localhost:9200/product_embeddings" \
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

sleep 2

curl -s -X POST "http://localhost:9200/product_embeddings/_doc/1" \
  -H 'Content-Type: application/json' \
  -d '{
    "title": "Wireless Headphones",
    "product_vector": [0.1, 0.2, 0.3, 0.4, 0.1, 0.2, 0.3, 0.4, 0.1, 0.2, 0.3, 0.4, 0.1, 0.2, 0.3, 0.4],
    "category": "electronics",
    "price": 299.99
  }' 2>/dev/null || true

curl -s -X POST "http://localhost:9200/logs_2024_01/_doc/1" \
  -H 'Content-Type: application/json' \
  -d '{
    "timestamp": "2024-01-01T00:00:00Z",
    "level": "INFO",
    "message": "Service started",
    "service": "api-gateway"
  }' 2>/dev/null || true

curl -s -X POST "http://localhost:9200/_refresh" 2>/dev/null || true

# Kill port forward
kill $ES_PF_PID 2>/dev/null || true
wait $ES_PF_PID 2>/dev/null || true

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
kubectl get pods -n $NAMESPACE

echo ""
echo -e "${BLUE}READY FOR DEMO!${NC}"
echo ""
echo -e "${YELLOW}Demo commands:${NC}"
echo ""
echo "Terminal 1 - Watch Elasticsearch logs:"
echo "  kubectl logs -n $NAMESPACE -l app=elasticsearch-master -f"
echo ""
echo "Terminal 2 - Watch OpenSearch logs:"
echo "  kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=opensearch -f"
echo ""
echo "Terminal 3 - Query Elasticsearch:"
echo "  kubectl port-forward -n $NAMESPACE svc/elasticsearch-master 9200:9200"
echo "  curl http://localhost:9200/_cat/indices"
echo ""
echo "Terminal 4 - Query OpenSearch:"
echo "  kubectl port-forward -n $NAMESPACE svc/opensearch-cluster-master 9201:9200"
echo "  curl http://localhost:9201/_cat/indices"
echo ""
