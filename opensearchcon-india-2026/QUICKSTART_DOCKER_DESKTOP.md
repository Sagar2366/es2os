# Docker Desktop Kubernetes - QUICK START

## ✅ Both Scripts Fixed!

---

## 🚀 FOR YOUR OPENSEARCHCON TALK (Pick One)

### OPTION 1: HELM (Recommended) ⭐ - 20 minutes

```bash
cd ~/es2os/opensearchcon-india-2026
git pull origin main
chmod +x DOCKER_DESKTOP_K8S_HELM.sh
./DOCKER_DESKTOP_K8S_HELM.sh
```

**Best for:** Demos, talks, presentations  
**Time:** 20 minutes  
**Reliability:** High  

---

### OPTION 2: Build from Source - 40-50 minutes

```bash
cd ~/es2os/opensearchcon-india-2026
git pull origin main
chmod +x DOCKER_DESKTOP_K8S_BUILD_SOURCE.sh
./DOCKER_DESKTOP_K8S_BUILD_SOURCE.sh
```

**Best for:** Production, full features  
**Time:** 40-50 minutes  
**Features:** Migration Assistant included  

---

## 📋 What Both Scripts Do

✅ Use Docker Desktop's Kubernetes  
✅ Deploy Elasticsearch (7.17 or 7.10)  
✅ Deploy OpenSearch (2.13 or 2.19)  
✅ Load sample data  
✅ Ready for demo  

---

## 🎬 After Setup - Demo in 4 Terminals

### Terminal 1: Query Elasticsearch
```bash
kubectl port-forward -n migration svc/elasticsearch-master 9200:9200
# Then: curl http://localhost:9200/_cat/indices
```

### Terminal 2: Query OpenSearch
```bash
kubectl port-forward -n migration svc/opensearch 9201:9200
# Then: curl http://localhost:9201/_cat/indices
```

### Terminal 3: Logs
```bash
kubectl logs -n migration -l app=elasticsearch-master -f
```

### Terminal 4: Status
```bash
kubectl get pods -n migration -w
```

---

## ✨ Key Differences

**Helm:**
- ✓ 20 min (ideal for before-talk setup)
- ✓ Simple, reliable
- ✓ Low resources (512MB each)

**Build from Source:**
- ✓ 40-50 min (comprehensive)
- ✓ Migration Assistant included
- ✓ Full production features

---

## 🎯 RECOMMENDATION

For your OpenSearchCon India 2026 talk on June 15:

**Use: DOCKER_DESKTOP_K8S_HELM.sh**

It's fast, simple, and perfect for a live demo!

---

## 📚 More Info

See: `DOCKER_DESKTOP_TWO_OPTIONS.md` for detailed comparison

