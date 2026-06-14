# KIND Cluster - Simple Execution Guide
## OpenSearchCon India 2026 Talk

**For use DURING your talk - straightforward, tested commands only**

---

## ⏱️ TOTAL TIME: 60 minutes (fully automated)

---

## ONE-COMMAND SETUP

```bash
cd ~/es2os/opensearchcon-india-2026
chmod +x KIND_AUTOMATED_SETUP.sh
./KIND_AUTOMATED_SETUP.sh
```

**Run this 60 minutes BEFORE your talk starts.**

The script will:
- ✅ Create Kind cluster
- ✅ Build all images (30-40 min wait)
- ✅ Deploy Elasticsearch 7.10 + OpenSearch 2.19
- ✅ Load sample data
- ✅ Show "SETUP COMPLETE" when done

---

## WHAT GETS INSTALLED AUTOMATICALLY

```
✓ kind (Kubernetes in Docker)
✓ kubectl (Kubernetes CLI)
✓ Docker verified running
✓ Java JDK 17 (if needed)
```

If any installation fails, script will tell you exactly what to install manually.

---

## DURING YOUR TALK - DEMO COMMANDS

### Terminal 1: Monitor Logs
```bash
kubectl logs -n migration -l app=migration-console --all-containers -f
```

### Terminal 2: Access Migration Console
```bash
kubectl exec -it migration-console-0 -n migration -- bash
```

Inside migration console:
```bash
# Check workflow status
workflow status

# View workflow logs
workflow logs

# Exit
exit
```

### Terminal 3: Query Elasticsearch (Source)
```bash
kubectl port-forward -n migration svc/elasticsearch-master 9200:9200
```

Then in another shell:
```bash
curl -k https://admin:admin@localhost:9200/_cat/indices
curl -k https://admin:admin@localhost:9200/product_embeddings/_search | jq '.hits.total'
```

### Terminal 4: Query OpenSearch (Target)
```bash
kubectl port-forward -n migration svc/opensearch-cluster-master 9201:9200
```

Then in another shell:
```bash
curl -k https://admin:admin@localhost:9201/_cat/indices
curl -k https://admin:admin@localhost:9201/product_embeddings/_search | jq '.hits.total'
```

---

## PRE-TALK CHECKLIST (30 min before)

Run these to verify everything is working:

```bash
# 1. Check all pods running
kubectl get pods -n migration

# Expected output:
# NAME                              READY   STATUS    RESTARTS
# migration-console-0               1/1     Running   0
# elasticsearch-master-0            1/1     Running   0
# opensearch-cluster-master-0       1/1     Running   0

# 2. Verify Elasticsearch has data
kubectl exec migration-console-0 -n migration -- \
  curl -s -k -u admin:admin https://elasticsearch-master:9200/_cat/indices

# 3. Verify OpenSearch has migrated data
kubectl exec migration-console-0 -n migration -- \
  curl -s -k -u admin:admin https://opensearch-cluster-master:9200/_cat/indices

# 4. Check no error logs
kubectl logs -n migration -l app=migration-console | grep -i error
```

If all show ✓ → You're ready!

---

## TROUBLESHOOTING (If something breaks)

### Issue: "Docker daemon not running"
```bash
# Start Docker
open -a Docker   # macOS
systemctl start docker   # Linux
```

### Issue: "kind: command not found"
```bash
# Install kind
brew install kind
# Then run setup script again
```

### Issue: Build stuck after 20 minutes
```bash
# Check if still building
tail -f /tmp/ma-build.log

# If completely stuck, restart
kind delete cluster --name opensearchcon-2026
./KIND_AUTOMATED_SETUP.sh
```

### Issue: Pod showing "ImagePullBackOff" or "Pending"
```bash
# Check what's wrong
kubectl describe pod migration-console-0 -n migration

# Restart cluster
kind delete cluster --name opensearchcon-2026
docker system prune -a
./KIND_AUTOMATED_SETUP.sh
```

### Issue: "workflow status" returns nothing
```bash
# Workflow might still be setting up
# Wait 2-3 minutes and try again
# Or check logs: kubectl logs -n migration -l app=migration-console
```

---

## CLUSTER INFO FOR REFERENCE

```
Cluster Name: opensearchcon-2026
Namespace: migration
Kubernetes Context: kind-opensearchcon-2026

Services:
- Elasticsearch 7.10: elasticsearch-master:9200
- OpenSearch 2.19: opensearch-cluster-master:9200
- Migration Console: migration-console:4571

Credentials (everywhere):
- Username: admin
- Password: admin
```

---

## DEMO FLOW (During Talk)

### Show Migration Analysis
```bash
# In migration console shell
workflow status
workflow logs | tail -20
```

### Show Data in Elasticsearch
```bash
# Terminal 3 (ES port-forward already running)
curl -k https://admin:admin@localhost:9200/_cat/indices
```

### Show Data Migrated to OpenSearch
```bash
# Terminal 4 (OS port-forward already running)
curl -k https://admin:admin@localhost:9201/_cat/indices
```

### Show Real-time Migration Logs
```bash
# Terminal 1 (logs already tailing)
# Just point at screen - shows all activity
```

---

## NETWORK PORTS (For local access)

When you run port-forward commands:

```
Elasticsearch:  localhost:9200  (via port-forward)
OpenSearch:     localhost:9201  (via port-forward)
```

After running port-forward, you can access from your laptop:
```bash
curl -k https://admin:admin@localhost:9200/_cat/indices
curl -k https://admin:admin@localhost:9201/_cat/indices
```

---

## IF SETUP FAILS COMPLETELY

```bash
# Nuclear option - clean everything
kind delete cluster --name opensearchcon-2026
docker system prune -a
docker image prune -a -f

# Then retry
./KIND_AUTOMATED_SETUP.sh
```

This takes ~60 min but will work.

---

## SUCCESS = THIS OUTPUT

When setup completes successfully, you'll see:

```
════════════════════════════════════════════════════════════════════
✓ SETUP COMPLETE
════════════════════════════════════════════════════════════════════

Next Commands:
  kubectl exec -it migration-console-0 -n migration -- bash
  kubectl logs -n migration -l app=migration-console -f
  kubectl port-forward -n migration svc/opensearch-cluster-master 9201:9200

Cluster Info:
  Cluster: opensearchcon-2026
  Namespace: migration
  ES: localhost:9200
  OS: localhost:9201
```

**When you see this → Your demo is ready!**

---

## QUICK REFERENCE CARD

Print this out and keep it next to your laptop during the talk:

```
SETUP (before talk):
./KIND_AUTOMATED_SETUP.sh    # 60 min, fully automated

DURING TALK (4 terminals):

Terminal 1 - Logs:
kubectl logs -n migration -l app=migration-console -f

Terminal 2 - Console:
kubectl exec -it migration-console-0 -n migration -- bash

Terminal 3 - ES Port:
kubectl port-forward -n migration svc/elasticsearch-master 9200:9200

Terminal 4 - OS Port:
kubectl port-forward -n migration svc/opensearch-cluster-master 9201:9200

QUERIES:
curl -k https://admin:admin@localhost:9200/_cat/indices
curl -k https://admin:admin@localhost:9201/_cat/indices

VERIFY (before talk):
kubectl get pods -n migration
```

---

**You're all set! Run the setup script 60 minutes before your talk, then use the commands above during your presentation.**

