# Docker Desktop Kubernetes - SIMPLE Approach

**Status:** ✅ No Complex Build Scripts | Direct Helm Deployment

---

## 🎯 What This Does

Uses **Helm charts** to directly deploy Elasticsearch and OpenSearch - much simpler than the Migration Assistant build approach.

**Time:** 15-20 minutes (vs 40 min with builds)

---

## ✅ Prerequisites

```bash
# 1. Docker Desktop with Kubernetes enabled
kubectl cluster-info

# 2. Helm installed
helm version

# If Helm not installed:
brew install helm
```

---

## 🚀 One-Command Setup

```bash
cd ~/es2os/opensearchcon-india-2026
chmod +x DOCKER_DESKTOP_K8S_SIMPLE.sh
./DOCKER_DESKTOP_K8S_SIMPLE.sh
```

---

## 📊 What Gets Deployed

| Component | Version | Purpose |
|-----------|---------|---------|
| Elasticsearch | 7.10 | Source cluster |
| OpenSearch | 2.19 | Target cluster |
| Kubernetes | Docker Desktop | Orchestrator |

---

## ⏱️ Timeline

| Time | Phase |
|------|-------|
| T-0 min | Start script |
| T-1 min | Create namespace |
| T-2 min | Deploy Elasticsearch (5-10 min wait) |
| T-12 min | Deploy OpenSearch (5-10 min wait) |
| T-15 min | Load sample data |
| T-18 min | DONE! |

---

## 🎬 4-Terminal Demo Setup

### Terminal 1: Elasticsearch Logs
```bash
kubectl port-forward -n migration svc/elasticsearch-master 9200:9200
# In another shell: curl http://localhost:9200/_cat/indices
```

### Terminal 2: OpenSearch Logs
```bash
kubectl port-forward -n migration svc/opensearch-cluster-master 9201:9200
# In another shell: curl http://localhost:9201/_cat/indices
```

### Terminal 3: Query ES Data
```bash
curl http://localhost:9200/_cat/indices
curl http://localhost:9200/product_embeddings/_search | jq '.hits.total'
```

### Terminal 4: Query OS Data
```bash
curl http://localhost:9201/_cat/indices
curl http://localhost:9201/product_embeddings/_search | jq '.hits.total'
```

---

## ✨ Advantages Over Migration Assistant Build

| Aspect | Migration Assistant | Helm Simple |
|--------|---------------------|------------|
| Setup time | 40+ min | 15-20 min |
| Complexity | High (builds from source) | Low (uses Helm charts) |
| Prerequisites | Java, Gradle, Docker | Helm, kubectl |
| Error likelihood | Higher | Lower |
| For quick demo | Not ideal | Perfect! |

---

## 📋 Success Indicators

When script completes:

```bash
$ kubectl get pods -n migration

NAME                           READY   STATUS    RESTARTS
elasticsearch-master-0         1/1     Running   0
opensearch-0                   1/1     Running   0
```

---

## 🆘 Troubleshooting

### "Pods stuck in Pending"
```bash
# Check events
kubectl describe pod elasticsearch-master-0 -n migration

# Check resources
kubectl top nodes
```

### "Port-forward fails"
```bash
# Make sure pod is Running first
kubectl get pods -n migration

# Try with explicit port
kubectl port-forward -n migration svc/elasticsearch-master 9200:9200 --address=127.0.0.1
```

### "Helm chart not found"
```bash
# Update Helm repos
helm repo add elastic https://helm.elastic.co
helm repo add opensearch https://opensearch-project.github.io/helm-charts/
helm repo update
```

---

## 🎉 That's It!

This is the **fastest, simplest** way to get Elasticsearch and OpenSearch running on Docker Desktop for your talk.

**Recommended for:** Quick demos and presentations

