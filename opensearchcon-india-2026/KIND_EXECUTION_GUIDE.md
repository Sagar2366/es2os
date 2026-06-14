# KIND Cluster Execution Guide - OpenSearchCon India 2026

**Status:** ✅ Fully Automated | No Manual Intervention

---

## 🚀 QUICK START

```bash
cd /path/to/es2os/opensearchcon-india-2026
chmod +x KIND_AUTOMATED_SETUP.sh
./KIND_AUTOMATED_SETUP.sh
```

**Total time:** ~50-60 minutes (fully automated, no manual intervention required)

---

## 📋 WHAT YOU GET

- ✅ Kind cluster with proper networking & port mappings
- ✅ Elasticsearch 7.10 + OpenSearch 2.19 pre-configured
- ✅ Migration Assistant with 3 test indices
- ✅ All 6 Kiro-identified issues **automatically fixed**
- ✅ Sample data with dense_vector mappings ready for conversion
- ✅ Workflow auto-submitted & approval gates auto-approved
- ✅ Production-grade setup for your OpenSearchCon talk

---

## 🔧 SYSTEM REQUIREMENTS

| Requirement | Minimum | Recommended |
|---|---|---|
| Memory | 20 GB | 24 GB |
| CPU | 4 cores | 8+ cores |
| Disk | 50 GB free | 100+ GB free |
| OS | macOS / Linux / WSL2 | macOS / Linux |

---

## 9-PHASE AUTOMATED BREAKDOWN

### PHASE 1: Prerequisites (2 min)
- Checks: kind, kubectl, docker, java
- Auto-installs missing tools via Homebrew
- Verifies Docker daemon running
- Reports system memory availability

### PHASE 2: Cleanup (1 min)
- Removes old "opensearchcon-2026" cluster if exists
- Prunes Docker images to free space

### PHASE 3: Kind Cluster Creation (5 min)
- Creates control-plane node
- Configures port mappings (30080, 30443, etc.)
- Waits for cluster readiness
- Verifies kubectl connectivity

### PHASE 4: Migration Assistant Prep (2 min)
- Clones opensearch-migrations v3.2.1 (if not cached)
- Sets KUBE_CONTEXT
- Prepares build environment

### PHASE 5: Image Builds (30-40 min)
**This is the main wait!**
- Builds migration-console
- Builds elasticsearch-master (7.10.2)
- Builds opensearch-cluster-master (2.19.5)
- Parallel builds with progress monitoring

**Kiro Fixes Applied:**
- ✅ JDK 17 configured
- ✅ Gradle cache optimized
- ✅ BuildKit parallel builds

### PHASE 6: Pod Deployment (10 min)
- Waits for migration-console ready state
- Waits for Elasticsearch pod (10 min timeout)
- Waits for OpenSearch pod (10 min timeout)
- Reports all pod status & services

### PHASE 7: Workflow Configuration (3 min)
**All 6 Kiro Fixes Applied Here:**

1. **Fix #1: Secret Labeling**
   ```yaml
   kubectl label secret source-credentials use-case=http-basic-credentials
   kubectl label secret target-credentials use-case=http-basic-credentials
   ```

2. **Fix #2: Dense Vector Mapping**
   ```json
   {
     "product_vector": {
       "type": "dense_vector",
       "dims": 768,
       "index": true,           // ← CRITICAL
       "similarity": "cosine"   // ← CRITICAL
     }
   }
   ```

3. **Fix #3: Sourceless Migrations**
   ```yaml
   enableSourcelessMigrations: true
   ```

4. **Fix #4: Auto-Approval Gates**
   - Script monitors and auto-approves workflow gates
   - No manual intervention needed

5. **Fix #5: Network Connectivity**
   - Uses internal DNS names (elasticsearch-master, opensearch-cluster-master)
   - Disables SSL verification (allowInsecure: true)

6. **Fix #6: JDK Matching**
   - Explicitly sets JAVA_HOME to JDK 17

### PHASE 8: Monitoring (5-10 min)
- Auto-approval loop monitors workflow status
- Detects approval gates and approves them
- Reports progress every 20 seconds
- Handles completion or failures gracefully

### PHASE 9: Final Verification (1 min)
- Queries OpenSearch for migrated data
- Verifies index count matches source
- Reports final status

---

## 🛠️ TROUBLESHOOTING

### "Docker daemon not running"
```bash
# macOS
open -a Docker

# Linux
systemctl start docker

# Windows
# Open Docker Desktop from Start Menu
```

### "kind: command not found"
```bash
brew install kind
# Then retry script
```

### "Build failed after 30 minutes"
```bash
# Solution 1: Increase Docker memory
# Docker Desktop → Preferences → Resources → Memory: 24GB

# Solution 2: Retry build
./KIND_AUTOMATED_SETUP.sh
# Script reuses cluster and continues from Phase 5

# Solution 3: Full restart
kind delete cluster --name opensearchcon-2026
docker system prune -a
./KIND_AUTOMATED_SETUP.sh
```

### "Pod stuck in Pending/ImagePullBackOff"
```bash
# Check events
kubectl describe pod migration-console-0 -n migration

# View logs
kubectl logs -n migration -l app=migration-console --all-containers

# If image build failed, check:
tail -100 /tmp/ma-build.log

# Restart everything
kind delete cluster --name opensearchcon-2026
./KIND_AUTOMATED_SETUP.sh
```

### "Workflow shows Failed"
```bash
# Get detailed logs
kubectl logs -n migration -l app=migration-console --all-containers

# Common fixes:
# 1. ES/OS connectivity: Check pod logs above
# 2. Secret auth failed: kubectl get secret -n migration
# 3. Mapping issue: Check dense_vector configuration
```

### "Script times out after 45 minutes"
```bash
# Check if still building
tail -f /tmp/ma-build.log

# If completed, manually verify
kubectl get pods -n migration
kubectl logs -n migration -l app=migration-console --all-containers

# Pod status commands
kubectl get pods -A
kubectl describe pods -n migration
```

---

## ✅ VERIFICATION CHECKLIST

After script completes, verify:

```bash
# 1. All pods running
kubectl get pods -n migration

# 2. Migration console responsive
kubectl exec migration-console-0 -n migration -- workflow status

# 3. Data in OpenSearch
kubectl exec migration-console-0 -n migration -- \
  curl -s -k -u admin:admin https://opensearch-cluster-master:9200/_cat/indices

# 4. Workflow completed
kubectl logs -n migration -l app=migration-console | grep -i completed

# 5. No errors in logs
kubectl logs -n migration -l app=migration-console --all-containers | grep -i error
```

---

## 🎬 NEXT STEPS

### Access Migration Console
```bash
kubectl exec -it migration-console-0 -n migration -- bash
```

### Check Workflow Status
```bash
kubectl exec migration-console-0 -n migration -- workflow status
kubectl exec migration-console-0 -n migration -- workflow logs
```

### Real-time Logs
```bash
kubectl logs -n migration -l app=migration-console --all-containers -f
```

### Port-Forward Services
```bash
# OpenSearch (new terminal)
kubectl port-forward -n migration svc/opensearch-cluster-master 9201:9200

# Elasticsearch (new terminal)
kubectl port-forward -n migration svc/elasticsearch-master 9200:9200
```

### Query Services
```bash
# Check indices
curl -k https://admin:admin@localhost:9200/_cat/indices

# Check migrated data
curl -k https://admin:admin@localhost:9201/_cat/indices
```

---

## 📊 KIRO FIXES SUMMARY

| Issue | Kiro Fix | Automation |
|-------|----------|-----------|
| Secret lookup failed | Label secrets with use-case | Auto-applied in Phase 7 |
| Dense vector conversion broken | Add index:true, similarity:cosine | Auto-applied in Phase 7 |
| Sourceless indices failed | enableSourcelessMigrations flag | Auto-applied in Phase 7 |
| Manual approval gates blocked | Auto-approval loop | Auto-applied in Phase 8 |
| Network connectivity issues | Internal DNS + allowInsecure | Auto-applied in Phase 7 |
| JDK version mismatch | Explicit JAVA_HOME setup | Auto-applied in Phase 5 |

---

## ⏱️ TIME BREAKDOWN

| Phase | Duration | Status |
|-------|----------|--------|
| 1. Prerequisites | 2 min | Auto-check & install |
| 2. Cleanup | 1 min | Auto-cleanup |
| 3. Kind Cluster | 5 min | Auto-create |
| 4. Prep Migrations | 2 min | Auto-download |
| 5. Build Images | **30-40 min** | Auto-build (main wait) |
| 6. Pod Deployment | 10 min | Auto-wait |
| 7. Configure Workflow | 3 min | Auto-configure + all 6 Kiro fixes |
| 8. Monitoring | 5-10 min | Auto-monitor + auto-approve |
| 9. Verification | 1 min | Auto-verify |
| **TOTAL** | **~50-60 min** | **FULLY AUTOMATED** |

---

## 🎯 YOU'RE READY WHEN YOU SEE:

```
════════════════════════════════════════════════════════════════════
✓ SETUP COMPLETE - ALL KIRO FIXES APPLIED
════════════════════════════════════════════════════════════════════

Applied Kiro Fixes:
  ✓ Fix #1: Secret labeling
  ✓ Fix #2: Dense vector mapping
  ✓ Fix #3: Sourceless migrations
  ✓ Fix #4: Auto-approval gates
  ✓ Fix #5: Network connectivity
  ✓ Fix #6: JDK version matching
```

This means your KIND cluster is fully configured and ready for the OpenSearchCon India 2026 talk! ☕

