# OpenSearchCon India 2026 - Demo Setup

## Two Options

### Option 1: Docker Desktop Kubernetes + Helm (RECOMMENDED - 20 min)
```bash
chmod +x DOCKER_DESKTOP_K8S_HELM.sh
./DOCKER_DESKTOP_K8S_HELM.sh
```

### Option 2: Docker Desktop Kubernetes + Build from Source (40-50 min)
```bash
chmod +x DOCKER_DESKTOP_K8S_BUILD_SOURCE.sh
./DOCKER_DESKTOP_K8S_BUILD_SOURCE.sh
```

### Option 3: Kind Cluster (60 min)
```bash
chmod +x KIND_AUTOMATED_SETUP.sh
./KIND_AUTOMATED_SETUP.sh
```

## Prerequisites
- Docker Desktop with Kubernetes enabled
- kubectl installed
- For Option 2: Java JDK 17

## After Setup - 4 Terminal Demo

**Terminal 1:**
```bash
kubectl port-forward -n migration svc/elasticsearch-master 9200:9200
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

## Recommendation for Your Talk
Use **Option 1** - it's the fastest and most reliable for a live demo.
