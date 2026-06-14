# Docker Desktop Kubernetes Setup - OpenSearchCon India 2026

**Status:** ✅ Faster Alternative to Kind | ~40 minutes total

---

## 🎯 ADVANTAGES OVER KIND

| Feature | Kind | Docker Desktop K8s |
|---------|------|-------------------|
| Setup Time | 60 min | **40 min** ⚡ |
| Pre-requisites | kind CLI needed | Docker Desktop only |
| Complexity | Separate cluster | Built-in |
| Network | Manual mapping | Automatic |
| Memory Overhead | Higher | Lower |
| **Recommendation** | Complex setups | **Talk demos** ✓ |

---

## 🚀 QUICK START

### Prerequisites (One-time setup)

1. **Install Docker Desktop** (if not already)
   - macOS: https://docs.docker.com/desktop/install/mac-install/
   - Windows: https://docs.docker.com/desktop/install/windows-install/

2. **Enable Kubernetes in Docker Desktop**
   - Open Docker Desktop
   - Go to: Preferences → Kubernetes
   - Check: ✓ "Enable Kubernetes"
   - Wait for it to finish (5-10 min)

3. **Verify Setup**
   ```bash
   kubectl cluster-info
   kubectl get nodes
   ```

### Run Setup (60 min before talk)

```bash
cd ~/es2os/opensearchcon-india-2026
chmod +x DOCKER_DESKTOP_K8S_SETUP.sh
./DOCKER_DESKTOP_K8S_SETUP.sh
```

Wait for: `✓ SETUP COMPLETE - DOCKER DESKTOP KUBERNETES`

---

## 📋 WHAT HAPPENS IN EACH PHASE

### PHASE 1: Check Docker Desktop & Kubernetes (1 min)
- Verify Docker running
- Verify Kubernetes enabled
- Check kubectl installed
- Report context (should be "docker-desktop")

### PHASE 2: Check System Resources (1 min)
- Reports Docker memory allocation
- Reports available system memory
- Warns if less than 16GB available

### PHASE 3: Cleanup (1 min)
- Removes old "migration" namespace
- Clears previous resources

### PHASE 4: Namespace & Migration Assistant (2 min)
- Creates "migration" namespace
- Downloads Migration Assistant v3.2.1 (if needed)

### PHASE 5: Build & Deploy (20-30 min) ⏱️
- Builds elasticsearch-master (ES 7.10)
- Builds opensearch-cluster-master (OS 2.19)
- Builds migration-console
- **Main wait time** - go grab coffee! ☕

### PHASE 6: Pod Readiness (5-10 min)
- Waits for migration-console
- Waits for elasticsearch
- Waits for opensearch
- Shows deployment status

### PHASE 7: Sample Data (2 min)
- Loads product_embeddings index (with dense_vector)
- Loads logs_2024_01 index
- Inserts sample documents

---

## ✅ VERIFICATION CHECKLIST (30 min before talk)

```bash
# 1. All pods running?
kubectl get pods -n migration

# Expected: All 3 pods show "1/1" and "Running"

# 2. Any errors?
kubectl logs -n migration -l app=migration-console | grep -i error

# Expected: No output

# 3. Data in Elasticsearch?
kubectl exec migration-console-0 -n migration -- \
  curl -s -k -u admin:admin https://elasticsearch-master:9200/_cat/indices

# Expected: See "product_embeddings" and "logs_2024_01"

# 4. Data in OpenSearch?
kubectl exec migration-console-0 -n migration -- \
  curl -s -k -u admin:admin https://opensearch-cluster-master:9200/_cat/indices

# Expected: See "product_embeddings" and "logs_2024_01"
```

If all OK → You're ready!

---

## 🎬 DEMO COMMANDS (Use during talk)

### Terminal 1: Watch Logs
```bash
kubectl logs -n migration -l app=migration-console --all-containers -f
```

### Terminal 2: Migration Console
```bash
kubectl exec -it migration-console-0 -n migration -- bash

# Inside console:
workflow status
workflow logs
exit
```

### Terminal 3: Query Elasticsearch (Source)
```bash
kubectl port-forward -n migration svc/elasticsearch-master 9200:9200

# In another shell:
curl -k https://admin:admin@localhost:9200/_cat/indices
curl -k https://admin:admin@localhost:9200/product_embeddings/_search | jq '.hits.total'
```

### Terminal 4: Query OpenSearch (Target)
```bash
kubectl port-forward -n migration svc/opensearch-cluster-master 9201:9200

# In another shell:
curl -k https://admin:admin@localhost:9201/_cat/indices
curl -k https://admin:admin@localhost:9201/product_embeddings/_search | jq '.hits.total'
```

---

## 🆘 TROUBLESHOOTING

### "Docker Desktop Kubernetes not enabled"
```bash
# Enable in UI:
Docker Desktop → Preferences → Kubernetes → Check "Enable Kubernetes"
# Then wait 5-10 minutes for it to start
```

### "kubectl: command not found"
```bash
# Kubernetes comes with Docker Desktop
# If not found, reinstall Docker Desktop and enable Kubernetes
```

### "Build failed after 20 minutes"
```bash
# Check logs:
tail -f /tmp/ma-build.log

# Restart script:
./DOCKER_DESKTOP_K8S_SETUP.sh
```

### "Pod stuck in Pending"
```bash
# Check what's wrong:
kubectl describe pod migration-console-0 -n migration

# Check node resources:
kubectl top nodes

# If out of memory:
# Docker Desktop → Preferences → Resources → Increase Memory
# Then restart: ./DOCKER_DESKTOP_K8S_SETUP.sh
```

### "Cannot connect to elasticsearch"
```bash
# Wait longer (pod might still be starting)
sleep 30
kubectl get pods -n migration

# If still stuck:
kubectl describe pod elasticsearch-master-0 -n migration
kubectl logs elasticsearch-master-0 -n migration
```

---

## ⏱️ TIMELINE

| T | Event |
|---|-------|
| T-40 min | Run setup script |
| T-35 min | Building images (20-30 min wait) |
| T-10 min | Pods coming online |
| T-5 min | Verification checklist |
| T-0 min | Your talk starts! |

---

## 📊 WHAT GETS CREATED

```
Kubernetes Context: docker-desktop
Namespace:          migration

Pods:
  - migration-console-0
  - elasticsearch-master-0
  - opensearch-cluster-master-0

Services:
  - elasticsearch-master:9200
  - opensearch-cluster-master:9200
  - migration-console:4571

Data:
  - product_embeddings (with dense_vector mapping)
  - logs_2024_01 (sample logs)

Credentials:
  - Username: admin
  - Password: admin (everywhere)
```

---

## 💡 KEY DIFFERENCES FROM KIND

| Aspect | Kind | Docker Desktop |
|--------|------|----------------|
| Installation | Separate `kind` CLI | Built into Docker |
| Memory Usage | ~20GB | ~15GB |
| Network Setup | Manual port mappings | Automatic |
| Image Registry | Kind registry | Docker registry |
| Multiple Clusters | Easy | One per Docker instance |
| Persistence | Per cluster | Survives Docker restart |
| **Best For** | CI/CD, complex setup | Local demo/development |

---

## ✨ BEFORE YOUR TALK (10 min)

1. Open Terminal 1 (logs)
2. Open Terminal 2 (console)
3. Open Terminal 3 (ES port-forward)
4. Open Terminal 4 (OS port-forward)
5. Keep KIND_SIMPLE_GUIDE.md open as reference

---

## 🎉 SUCCESS MESSAGE

When setup completes, you'll see:

```
════════════════════════════════════════════════════════════════════
✓ SETUP COMPLETE - DOCKER DESKTOP KUBERNETES
════════════════════════════════════════════════════════════════════

Cluster Status:
NAME                           READY   STATUS
migration-console-0            1/1     Running
elasticsearch-master-0         1/1     Running
opensearch-cluster-master-0    1/1     Running

READY FOR DEMO!

During your talk, use these commands:
  Terminal 1 - Watch logs:
    kubectl logs -n migration -l app=migration-console -f
  
  Terminal 2 - Access migration console:
    kubectl exec -it migration-console-0 -n migration -- bash
  
  Terminal 3 - Query Elasticsearch:
    kubectl port-forward -n migration svc/elasticsearch-master 9200:9200
  
  Terminal 4 - Query OpenSearch:
    kubectl port-forward -n migration svc/opensearch-cluster-master 9201:9200
```

**When you see this → You're ready for your talk!**

---

## 🔗 REFERENCE

- Script: `DOCKER_DESKTOP_K8S_SETUP.sh`
- Demo commands: `KIND_SIMPLE_GUIDE.md` (same commands work!)
- Troubleshooting: This file

---

**Recommended:** Use Docker Desktop Kubernetes for your talk - it's faster and simpler!

