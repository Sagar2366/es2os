#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════════
# DOCKER DESKTOP KUBERNETES - HELM CHARTS (FIXED)
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
echo -e "${BLUE}Docker Desktop Kubernetes - Helm Charts (FIXED)${NC}"
echo -e "${BLUE}OpenSearchCon India 2026${NC}"
echo -e "${BLUE}Time: ~5-10 minutes${NC}"
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
echo -e "${YELLOW}PHASE 2: Cleaning up old resources...${NC}"

if kubectl get namespace $NAMESPACE &> /dev/null; then
  echo -e "${YELLOW}  Deleting namespace...${NC}"
  kubectl delete namespace $NAMESPACE --wait=false 2>/dev/null || true
  sleep 3
fi

# Clean up any Helm releases
helm uninstall elasticsearch -n $NAMESPACE 2>/dev/null || true
helm uninstall opensearch -n $NAMESPACE 2>/dev/null || true

echo -e "${GREEN}✓ Cleanup complete${NC}"
echo ""

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 3: PRE-PULL IMAGES TO LOCAL DOCKER
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}PHASE 3: Pre-pulling Docker images locally...${NC}"
echo -e "${BLUE}  This avoids Docker Desktop image pull issues${NC}"

echo -e "${YELLOW}  Pulling Elasticsearch 8.5.1...${NC}"
docker pull docker.elastic.co/elasticsearch/elasticsearch:8.5.1 &> /dev/null &
ES_PID=$!

echo -e "${YELLOW}  Pulling OpenSearch 2.13.0...${NC}"
docker pull opensearchproject/opensearch:2.13.0 &> /dev/null &
OS_PID=$!

wait $ES_PID $OS_PID 2>/dev/null || true

echo -e "${GREEN}✓ Images pulled${NC}"
echo ""

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 4: CREATE NAMESPACE
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}PHASE 4: Creating namespace...${NC}"

kubectl create namespace $NAMESPACE
kubectl label namespace $NAMESPACE name=$NAMESPACE 2>/dev/null || true

echo -e "${GREEN}✓ Namespace created${NC}"
echo ""

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 5: DEPLOY ELASTICSEARCH & OPENSEARCH AS SIMPLE PODS
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}PHASE 5: Deploying Elasticsearch and OpenSearch...${NC}"

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: elasticsearch
  namespace: migration
  labels:
    app: elasticsearch
spec:
  containers:
  - name: elasticsearch
    image: docker.elastic.co/elasticsearch/elasticsearch:8.5.1
    ports:
    - containerPort: 9200
    env:
    - name: discovery.type
      value: "single-node"
    - name: ES_JAVA_OPTS
      value: "-Xms256m -Xmx256m"
    - name: xpack.security.enabled
      value: "false"
    resources:
      requests:
        memory: "256Mi"
        cpu: "100m"
      limits:
        memory: "512Mi"
        cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: elasticsearch
  namespace: migration
spec:
  selector:
    app: elasticsearch
  ports:
  - port: 9200
    targetPort: 9200
  type: ClusterIP
---
apiVersion: v1
kind: Pod
metadata:
  name: opensearch
  namespace: migration
  labels:
    app: opensearch
spec:
  containers:
  - name: opensearch
    image: opensearchproject/opensearch:2.13.0
    ports:
    - containerPort: 9200
    env:
    - name: discovery.type
      value: "single-node"
    - name: OPENSEARCH_JAVA_OPTS
      value: "-Xms256m -Xmx256m"
    - name: DISABLE_SECURITY_PLUGIN
      value: "true"
    resources:
      requests:
        memory: "256Mi"
        cpu: "100m"
      limits:
        memory: "512Mi"
        cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: opensearch
  namespace: migration
spec:
  selector:
    app: opensearch
  ports:
  - port: 9200
    targetPort: 9200
  type: ClusterIP
EOF

echo -e "${YELLOW}  Waiting for pods to be ready...${NC}"

# Wait for both pods
for i in {1..60}; do
  ES_READY=$(kubectl get pod elasticsearch -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
  OS_READY=$(kubectl get pod opensearch -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
  
  if [[ "$ES_READY" == "True" && "$OS_READY" == "True" ]]; then
    echo -e "${GREEN}✓ All pods ready${NC}"
    break
  fi
  
  if [ $((i % 10)) -eq 0 ]; then
    echo -e "${BLUE}  Still waiting... ($i/60 seconds)${NC}"
  fi
  
  sleep 1
done

echo ""

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 6: LOAD SAMPLE DATA
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}PHASE 6: Loading sample data...${NC}"

sleep 5

# Port forward to load data
kubectl port-forward -n $NAMESPACE svc/elasticsearch 9200:9200 > /dev/null 2>&1 &
PF_PID=$!
sleep 3

# Create index
curl -s -X PUT "http://localhost:9200/products" \
  -H 'Content-Type: application/json' \
  -d '{"mappings": {"properties": {"title": {"type": "text"}, "price": {"type": "float"}}}}' \
  > /dev/null 2>&1 || true

# Insert sample data
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
kill $PF_PID 2>/dev/null || true
wait $PF_PID 2>/dev/null || true

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
echo -e "${YELLOW}Demo Commands (Open 4 Terminals):${NC}"
echo ""
echo "Terminal 1 - Query Elasticsearch:"
echo "  kubectl port-forward -n migration svc/elasticsearch 9200:9200"
echo "  curl http://localhost:9200/_cat/indices"
echo ""
echo "Terminal 2 - Query OpenSearch:"
echo "  kubectl port-forward -n migration svc/opensearch 9201:9200"
echo "  curl http://localhost:9201/_cat/indices"
echo ""
echo "Terminal 3 - Elasticsearch Logs:"
echo "  kubectl logs -n migration elasticsearch -f"
echo ""
echo "Terminal 4 - OpenSearch Logs:"
echo "  kubectl logs -n migration opensearch -f"
echo ""
echo -e "${GREEN}✅ READY FOR DEMO!${NC}"
echo ""
