# ⭐ START HERE - Docker Desktop Kubernetes Setup

## 🎯 For Your OpenSearchCon India 2026 Talk (RECOMMENDED)

This is the **fastest and simplest** way to set up your demo.

---

## ✅ Prerequisites (5 minutes)

### 1. Have Docker Desktop Installed
- macOS: https://docs.docker.com/desktop/install/mac-install/
- Windows: https://docs.docker.com/desktop/install/windows-install/

### 2. Enable Kubernetes in Docker Desktop
```
Open Docker Desktop
  → Preferences (or Settings on Windows)
  → Kubernetes tab
  → Check "Enable Kubernetes"
  → Click "Apply & Restart"
  → Wait 5-10 minutes for it to start
```

### 3. Verify Setup
```bash
kubectl cluster-info
# Should show: Kubernetes control plane is running at https://...
```

---

## 🚀 ONE-COMMAND SETUP (40 minutes)

**Run this 40 minutes BEFORE your talk:**

```bash
cd ~/es2os/opensearchcon-india-2026
chmod +x DOCKER_DESKTOP_K8S_SETUP.sh
./DOCKER_DESKTOP_K8S_SETUP.sh
```

That's it! The script handles everything.

**When you see this message, you're done:**
```
✓ SETUP COMPLETE - DOCKER DESKTOP KUBERNETES
READY FOR DEMO!
```

---

## 📋 Timeline

| Time | Action |
|------|--------|
| T-40 min | Run setup script |
| T-30 min | Building images (grab coffee ☕) |
| T-5 min | Verification checklist |
| T-0 min | Your talk starts! |

---

## ✅ Before Your Talk (5 minutes)

Run this verification checklist 30 minutes before:

```bash
# 1. All pods running?
kubectl get pods -n migration

# Expected: All 3 show "1/1" and "Running"

# 2. Any errors?
kubectl logs -n migration -l app=migration-console | grep -i error

# Expected: No output

# If both OK → You're ready!
```

---

## 🎬 During Your Talk (Setup 4 terminals)

### Terminal 1: Watch Logs (Point at this!)
```bash
kubectl logs -n migration -l app=migration-console -f
```

### Terminal 2: Console Access
```bash
kubectl exec -it migration-console-0 -n migration -- bash
# Inside: workflow status
```

### Terminal 3: Query Elasticsearch
```bash
kubectl port-forward -n migration svc/elasticsearch-master 9200:9200
# In another shell: curl -k https://admin:admin@localhost:9200/_cat/indices
```

### Terminal 4: Query OpenSearch
```bash
kubectl port-forward -n migration svc/opensearch-cluster-master 9201:9200
# In another shell: curl -k https://admin:admin@localhost:9201/_cat/indices
```

---

## 📊 What You Get

✓ Elasticsearch 7.10 (source)  
✓ OpenSearch 2.19 (target)  
✓ Migration Assistant  
✓ Sample data ready  
✓ Real-time logs  
✓ Pre-configured auth  

---

## 🆘 If Something Goes Wrong

### "Kubernetes not enabled"
```
Docker Desktop → Preferences → Kubernetes → Enable
Wait 5-10 minutes
```

### "Build stuck after 20 min"
```bash
tail -f /tmp/ma-build.log
# If stuck, restart: ./DOCKER_DESKTOP_K8S_SETUP.sh
```

### "Pod not starting"
```bash
kubectl describe pod migration-console-0 -n migration
# If memory issue: increase Docker Desktop memory limits
```

---

## 📖 Reference Files

- `CHOOSE_YOUR_SETUP.md` - Understand Docker Desktop vs Kind
- `DOCKER_DESKTOP_K8S_GUIDE.md` - Detailed guide
- `KIND_SIMPLE_GUIDE.md` - Demo commands (print this!)
- `OPENSEARCHCON_KIND_EXECUTION_CHECKLIST.txt` - Step-by-step checklist

---

## 🎉 That's It!

You're ready for your talk. Simple as:

1. Enable Kubernetes in Docker Desktop
2. Run the setup script (40 min)
3. Run verification checklist (5 min)
4. Open 4 demo terminals (5 min)
5. Give your amazing talk! 🚀

---

**Questions?** See: `CHOOSE_YOUR_SETUP.md` or `DOCKER_DESKTOP_K8S_GUIDE.md`

