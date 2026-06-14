# KIND Cluster Demo Setup - OpenSearchCon India 2026

## 📋 WHAT YOU HAVE

✅ **KIND_AUTOMATED_SETUP.sh** - Full automation script  
✅ **KIND_SIMPLE_GUIDE.md** - Talk-ready quick reference (READ THIS FIRST)  
✅ **KIND_EXECUTION_GUIDE.md** - Detailed breakdown (optional reference)  

---

## 🚀 BEFORE YOUR TALK (60 minutes)

**Run this ONE command:**

```bash
cd ~/es2os/opensearchcon-india-2026
chmod +x KIND_AUTOMATED_SETUP.sh
./KIND_AUTOMATED_SETUP.sh
```

**That's it.** The script handles everything automatically.

When you see this, you're ready:
```
✓ SETUP COMPLETE
READY FOR DEMO!
```

**Time:** ~60 minutes (fully automated, no interaction needed)

---

## 🎬 DURING YOUR TALK (Use KIND_SIMPLE_GUIDE.md)

Open **KIND_SIMPLE_GUIDE.md** - it has all the demo commands you need.

Key sections:
- **DURING YOUR TALK - DEMO COMMANDS** ← Use these 4 terminal setups
- **PRE-TALK CHECKLIST** ← Run these 30 min before
- **QUICK REFERENCE CARD** ← Print and keep by laptop

---

## 📖 FILE PURPOSES

| File | Use Case |
|------|----------|
| **KIND_AUTOMATED_SETUP.sh** | Run this 60 min before talk |
| **KIND_SIMPLE_GUIDE.md** | Reference during talk (PRINT THIS) |
| **KIND_EXECUTION_GUIDE.md** | Optional deep-dive reference |
| **README_KIND_DEMO.md** | This file - overview |

---

## ✅ VERIFICATION (30 min before talk)

```bash
# 1. All pods running?
kubectl get pods -n migration

# 2. Any errors?
kubectl logs -n migration -l app=migration-console | grep -i error

# If both OK → You're ready!
```

---

## 🎯 DEMO FLOW

**Terminal 1:** Watch migration logs
```bash
kubectl logs -n migration -l app=migration-console -f
```

**Terminal 2:** Access migration console  
```bash
kubectl exec -it migration-console-0 -n migration -- bash
workflow status
```

**Terminal 3:** Show Elasticsearch data
```bash
kubectl port-forward -n migration svc/elasticsearch-master 9200:9200
# In another shell: curl -k https://admin:admin@localhost:9200/_cat/indices
```

**Terminal 4:** Show OpenSearch data
```bash
kubectl port-forward -n migration svc/opensearch-cluster-master 9201:9200
# In another shell: curl -k https://admin:admin@localhost:9201/_cat/indices
```

---

## 🆘 IF SOMETHING BREAKS

1. Check: `kubectl get pods -n migration`
2. If pod crashed: `kubectl describe pod <pod-name> -n migration`
3. Full restart: 
   ```bash
   kind delete cluster --name opensearchcon-2026
   docker system prune -a
   ./KIND_AUTOMATED_SETUP.sh
   ```

---

## 💡 WHAT'S HAPPENING

The setup creates:
- Kubernetes cluster (Kind)
- Elasticsearch 7.10 (source)
- OpenSearch 2.19 (target)
- Migration Assistant (orchestrator)
- Sample data with proper mappings

Total size: ~15GB (built locally)

---

## ⏱️ TIMELINE

| When | Action |
|------|--------|
| T-60 min | Run `./KIND_AUTOMATED_SETUP.sh` |
| T-30 min | Run pre-talk verification |
| T-10 min | Open 4 terminals with demo commands |
| T-0 min | Start talk, point at Terminal 1 logs |

---

## ✅ YOU'RE READY WHEN

```bash
$ ./KIND_AUTOMATED_SETUP.sh
# ... 60 minutes of building ...

✓ SETUP COMPLETE
READY FOR DEMO!

Cluster Status:
NAME                              READY   STATUS
migration-console-0               1/1     Running
elasticsearch-master-0            1/1     Running
opensearch-cluster-master-0       1/1     Running
```

**Then proceed to KIND_SIMPLE_GUIDE.md for demo commands.**

