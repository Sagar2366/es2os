# Two Setup Options for Docker Desktop Kubernetes

## 🎯 Choose Your Path

### Option 1: Helm Charts (RECOMMENDED) ⭐
**Time:** 20 minutes  
**Script:** `DOCKER_DESKTOP_K8S_HELM.sh`  
**Best For:** Quick demos, talks, presentations  

```bash
chmod +x DOCKER_DESKTOP_K8S_HELM.sh
./DOCKER_DESKTOP_K8S_HELM.sh
```

**Advantages:**
- ✅ Fast (20 min vs 40+ min)
- ✅ Simple (uses stable Helm charts)
- ✅ Low resource usage (512MB each container)
- ✅ Easy troubleshooting (standard charts)

---

### Option 2: Build From Source ⚙️
**Time:** 40-50 minutes  
**Script:** `DOCKER_DESKTOP_K8S_BUILD_SOURCE.sh`  
**Best For:** Production-grade setup, full control  

```bash
chmod +x DOCKER_DESKTOP_K8S_BUILD_SOURCE.sh
./DOCKER_DESKTOP_K8S_BUILD_SOURCE.sh
```

**Advantages:**
- ✅ Builds from latest source code
- ✅ Migration Assistant included (for complex migrations)
- ✅ More control over deployment
- ✅ Production-ready setup

---

## 📊 Comparison

| Feature | Helm | Build From Source |
|---------|------|------------------|
| Time | **20 min** | 40-50 min |
| Complexity | Simple | Complex |
| Resource Use | Low (512MB) | Higher |
| Migration Assistant | No | Yes |
| Best For | **Demos/Talks** | Production |
| Troubleshooting | Easy | Moderate |

---

## 🚀 Quick Decision

**For Your OpenSearchCon Talk:** Use **Helm** (Option 1)
- It's fast
- It's simple
- It works reliably
- Perfect for 40-minute demo

**For Production/Lab:** Use **Build From Source** (Option 2)
- More features
- Full control
- Migration Assistant included

---

## ✅ Prerequisites (Both)

```bash
# 1. Docker Desktop with Kubernetes enabled
kubectl cluster-info

# 2. Helm installed (only needed for Helm option)
brew install helm
# OR already included with Docker Desktop
```

---

## 🎬 After Setup - Demo Commands (Both)

### Terminal 1: Elasticsearch
```bash
kubectl port-forward -n migration svc/elasticsearch-master 9200:9200
```

### Terminal 2: OpenSearch  
```bash
kubectl port-forward -n migration svc/opensearch-cluster-master 9201:9200
# OR (for Helm setup):
kubectl port-forward -n migration svc/opensearch 9201:9200
```

### Terminal 3: Query ES
```bash
curl http://localhost:9200/_cat/indices
curl http://localhost:9200/products/_search | jq
```

### Terminal 4: Query OS
```bash
curl http://localhost:9201/_cat/indices
curl http://localhost:9201/products/_search | jq
```

---

## 🆘 Troubleshooting

### For Helm Setup
```bash
# Check Helm releases
helm list -n migration

# Check pod issues
kubectl describe pod elasticsearch-0 -n migration

# See Helm deployment values
helm values elasticsearch -n migration
```

### For Build From Source
```bash
# Check migration console
kubectl logs -n migration -l app=migration-console

# See what got built
docker image ls | grep migration

# Check build errors
tail -50 /tmp/ma-build.log
```

---

## 📋 Success Indicators

Both setups should show:
```bash
$ kubectl get pods -n migration
NAME                           READY   STATUS    RESTARTS
elasticsearch-xxxx             1/1     Running   0
opensearch-xxxx                1/1     Running   0
```

And data should exist:
```bash
$ curl http://localhost:9200/_cat/indices
products    open
```

---

## 🎉 Recommendation

**For your OpenSearchCon India 2026 talk:**

```bash
./DOCKER_DESKTOP_K8S_HELM.sh
```

It's the fastest, simplest, and most reliable for a live presentation!

