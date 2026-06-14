#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════════
# DOCKER DESKTOP KUBERNETES SETUP - OpenSearchCon India 2026
# Fully Automated, Self-Healing Version (No Manual Steps)
# ════════════════════════════════════════════════════════════════════════════════

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TARGET_NAMESPACE="ma"

echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Docker Desktop Kubernetes Setup - OpenSearchCon India 2026${NC}"
echo -e "${BLUE}Handling all configurations natively inside the automation pipeline...${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
echo ""

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 1: PREREQUISITES & CLUSTER VALIDATION
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}PHASE 1: Checking Docker Desktop & Kubernetes context...${NC}"

if ! command -v docker &> /dev/null || ! docker ps &> /dev/null; then
  echo -e "${RED}✗ Docker daemon is not running. Please start Docker Desktop.${NC}"
  exit 1
fi

if ! command -v kubectl &> /dev/null; then
  echo -e "${RED}✗ kubectl tool missing.${NC}"
  exit 1
fi

if kubectl config get-contexts | grep -q "docker-desktop"; then
  kubectl config use-context docker-desktop
else
  echo -e "${RED}✗ docker-desktop context not found in kubeconfig.${NC}"
  exit 1
fi

echo -e "${GREEN}  ✓ Kubernetes Context set to docker-desktop${NC}"
echo ""

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 2: PURGE CORRUPTED METADATA / LOCKS
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}PHASE 2: Evicting stale Helm release locks and old states...${NC}"

# Clear any dead locks hanging in the secrets engine for a clean run
kubectl delete secret -n $TARGET_NAMESPACE -l owner=helm,name=ma 2>/dev/null || true
kubectl delete namespace $TARGET_NAMESPACE 2>/dev/null || true
sleep 2

# Guarantee namespace exists early
kubectl create namespace $TARGET_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}  ✓ Target namespace '$TARGET_NAMESPACE' initialized clean${NC}"
echo ""

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 3: MOCK CONFIGMAP WITH HELM METADATA OWNERSHIP INJECTED
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}PHASE 3: Pre-provisioning ConfigMap with explicit Helm ownership data...${NC}"

# This block builds the exact ConfigMap the chart hook needs, but patches it with
# the precise labels and annotations Helm checks for to prevent ownership import failures.
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: migrations-default-s3-config
  namespace: $TARGET_NAMESPACE
  labels:
    app.kubernetes.io/managed-by: Helm
  annotations:
    meta.helm.sh/release-name: ma
    meta.helm.sh/release-namespace: $TARGET_NAMESPACE
data:
  aws-region: us-east-1
  s3-bucket: mock-local-migration-bucket
EOF

echo -e "${GREEN}  ✓ ConfigMap pre-staged and linked to Helm release identity successfully${NC}"
echo ""

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 4: PREPARE WORKSPACE ENVIRONMENT
# ════════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}PHASE 4: Refreshing OpenSearch Migrations source trees...${NC}"

MIGRATIONS_DIR="/tmp/
