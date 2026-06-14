# OpenSearchCon India 2026 - Demo Setup

## Recommended: Docker Desktop Kubernetes + Simple Pods (FIXED)

```bash
chmod +x DOCKER_DESKTOP_K8S_HELM.sh
./DOCKER_DESKTOP_K8S_HELM.sh
```

**What it does:**
- Pre-pulls Docker images locally (avoids Docker Desktop image pull issues)
- Deploys Elasticsearch 8.5 + OpenSearch 2.13 as simple Kubernetes pods
- Loads sample data
- Ready in ~5-10 minutes

**Note:** This version is fixed to work reliably with Docker Desktop Kubernetes by:
1. Pre-pulling images to local Docker first
2. Using simple pod deployments instead of Helm charts
3. Handling resource constraints properly

---

## Alternative: Build from Source (40-50 min)

```bash
chmod +x DOCKER_DESKTOP_K8S_BUILD_SOURCE.sh
./DOCKER_DESKTOP_K8S_BUILD_SOURCE.sh
```

---

## Alternative: Kind Cluster (60 min)

```bash
chmod +x KIND_AUTOMATED_SETUP.sh
./KIND_AUTOMATED_SETUP.sh
```

---

## After Setup - 4 Terminal Demo

**Terminal 1:**
```bash
kubectl port-forward -n migration svc/elasticsearch 9200:9200
```

**Terminal 2:**
```bash
kubectl port-forward -n migration svc/opensearch 9201:9200
```

**Terminal 3:**
```bash
curl http://localhost:9200/_cat/indices
curl http://localhost:9200/products/_search | jq
```

**Terminal 4:**
```bash
curl http://localhost:9201/_cat/indices
curl http://localhost:9201/products/_search | jq
```

---

## Prerequisites

- Docker Desktop with Kubernetes enabled
- kubectl installed
- 512MB+ free memory

---

## Recommendation

**For your OpenSearchCon talk:** Use the first option (DOCKER_DESKTOP_K8S_HELM.sh)
- Fastest and most reliable
- Works with Docker Desktop image pulling
- Ready in 5-10 minutes
