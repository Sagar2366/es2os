#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════════
# DOCKER DESKTOP KUBERNETES - HELM CHARTS (Simple)
# OpenSearchCon India 2026
# ════════════════════════════════════════════════════════════════════════════════

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="migration"

echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Docker Desktop Kubernetes - Helm Charts${NC}"
echo -e "${BLUE}OpenSearchCon India 2026${NC}"
echo -e "${BLUE}Time: ~20 minutes (MUCH FASTER!)${NC}"
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

if ! command -v helm &> /dev/null; then
  echo -e "${RED}✗ Helm not found. Installing...${NC}"
  brew install helm
fi
echo -e "${GREEN}  ✓ Helm installed${NC}"

echo -e "${GREEN}✓ Prerequisites OK${NC}"
echo ""

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 2: CLEANUP
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}PHASE 2: Cleaning up...${NC}"

if kubectl get namespace $NAMESPACE &> /dev/null; then
  echo -e "${YELLOW}  Deleting namespace...${NC}"
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
kubectl label namespace $NAMESPACE name=$NAMESPACE 2>/dev/null || true

echo -e "${GREEN}✓ Namespace created${NC}"
echo ""

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 4: ADD HELM REPOS
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}PHASE 4: Adding Helm repositories...${NC}"

helm repo add elastic https://helm.elastic.co 2>/dev/null || helm repo update elastic
helm repo add opensearch https://opensearch-project.github.io/helm-charts/ 2>/dev/null || helm repo update opensearch
helm repo update

echo -e "${GREEN}✓ Helm repos ready${NC}"
echo ""

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 5: DEPLOY ELASTICSEARCH WITH LOW RESOURCES
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}PHASE 5: Deploying Elasticsearch 7.17...${NC}"

helm install elasticsearch elastic/elasticsearch \
  --version 7.17.0 \
  -n $NAMESPACE \
  --set replicas=1 \
  --set volumeClaimTemplate.storageClassName="standard" \
  --set "resources.requests.memory=512Mi" \
  --set "resources.requests.cpu=200m" \
  --set "resources.limits.memory=1Gi" \
  --set "resources.limits.cpu=500m" \
  --set "xpack.security.enabled=false" \
  --set "minimumMasterNodes=1" \
  2>&1 | grep -E "(NAME|STATUS|NOTES|release)" || true

echo -e "${YELLOW}  Waiting for Elasticsearch...${NC}"
kubectl wait --for=condition=ready pod -l app=elasticsearch-master -n $NAMESPACE --timeout=10m 2>/dev/null || {
  echo -e "${YELLOW}  Still starting...${NC}"
}

echo -e "${GREEN}✓ Elasticsearch deployed${NC}"
echo ""

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 6: DEPLOY OPENSEARCH WITH LOW RESOURCES
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}PHASE 6: Deploying OpenSearch 2.13...${NC}"

helm install opensearch opensearch/opensearch \
  --version 2.13.0 \
  -n $NAMESPACE \
  --set "replicas=1" \
  --set "resources.requests.memory=512Mi" \
  --set "resources.requests.cpu=200m" \
  --set "resources.limits.memory=1Gi" \
  --set "resources.limits.cpu=500m" \
  --set "opensearchJavaOpts=-Xms512m -Xmx512m" \
  --set "plugins.security.enabled=false" \
  2>&1 | grep -E "(NAME|STATUS|NOTES|release)" || true

echo -e "${YELLOW}  Waiting for OpenSearch...${NC}"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=opensearch -n $NAMESPACE --timeout=10m 2>/dev/null || {
  echo -e "${YELLOW}  Still starting...${NC}"
}

echo -e "${GREEN}✓ OpenSearch deployed${NC}"
echo ""

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 7: LOAD SAMPLE DATA
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}PHASE 7: Loading sample data...${NC}"

sleep 5

# Port forward ES in background
kubectl port-forward -n $NAMESPACE svc/elasticsearch-master 9200:9200 > /dev/null 2>&1 &
ES_PF_PID=$!
sleep 3

# Create index
curl -s -X PUT "http://localhost:9200/products" \
  -H 'Content-Type: application/json' \
  -d '{"mappings": {"properties": {"title": {"type": "text"}, "price": {"type": "float"}}}}' \
  > /dev/null 2>&1 || true

# Insert data
curl -s -X POST "http://localhost:9200/products/_doc/1" \
  -H 'Content-Type: application/json' \
  -d '{"title": "Wireless Headphones", "price": 299.99}' \
  > /dev/null 2>&1 || true

curl -s -X POST "http://localhost:9200/products/_doc/2" \
  -H 'Content-Type: application/json' \
  -d '{"title": "USB-C Cable", "price": 19.99}' \
  > /dev/null 2>&1 || true

curl -s -X POST "http://localhost:9200/_refresh" > /dev/null 2>&1 || true

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

echo -e "${BLUE}Pod Status:${NC}"
kubectl get pods -n $NAMESPACE

echo ""
echo -e "${YELLOW}Demo Commands:${NC}"
echo ""
echo "Terminal 1 - Query Elasticsearch:"
echo "  kubectl port-forward -n migration svc/elasticsearch-master 9200:9200"
echo "  curl http://localhost:9200/_cat/indices"
echo ""
echo "Terminal 2 - Query OpenSearch:"
echo "  kubectl port-forward -n migration svc/opensearch 9201:9200"
echo "  curl http://localhost:9201/_cat/indices"
echo ""
echo "Terminal 3 - Elasticsearch Logs:"
echo "  kubectl logs -n migration -l app=elasticsearch-master -f"
echo ""
echo "Terminal 4 - OpenSearch Logs:"
echo "  kubectl logs -n migration -l app.kubernetes.io/name=opensearch -f"
echo ""
