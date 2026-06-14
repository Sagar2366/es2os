# OpenSearchCon India 2026 - TALK CHEAT SHEET
## Quick Commands & Talking Points (Print This!)

---

## PRE-TALK CHECKLIST (Run 30 min before)
```bash
# Terminal 1: Verify services
docker ps | grep -E "es-source|os-target" && echo "✅ All running"

# Terminal 2: Keep this open for logs
docker logs -f logstash-migration | grep -E "Migrated|Index|error"

# Terminal 3: Ready for live commands
cd ~/Desktop/es2os
```

---

## PHASE 1: ANALYSIS (8 min) - Copy/Paste Commands

### Command 1: Full Report (2 min)
```bash
./es2os report --file testdata/es7_full_cluster.json --source-version 7.17.27 --target-version 2.19.5
```
**Say:** "7 indices, 4 critical issues, ❌ NOT READY — this is what blocks your migration"

### Command 2: Show Transformation (2 min)  
```bash
./es2os transform --file testdata/es7_full_cluster.json | jq '.indices.product_embeddings'
```
**Say:** "dense_vector becomes knn_vector with HNSW — miss this and vector search breaks"

### Command 3: HTML Report (1 min)
```bash
./es2os report --file testdata/es7_full_cluster.json -o html --html-file /tmp/report.html
open /tmp/report.html
```
**Say:** "Share this with your team — it's self-contained HTML, no setup needed"

---

## PHASE 2: TRANSFORMATION (10 min)

### Show Docker Compose
```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
```
**Say:** "ES 7.17 on 9200, OpenSearch 2.19 on 9201, connected via Logstash"

### Show Logstash Config
```bash
cat logstash/pipelines/migrate-all.conf | head -25
```
**Highlight:**
- `index => "*,-.*"` — read ALL indices
- `scroll => "5m"` — doesn't timeout
- `retry_on_conflict => 3` — auto-retry on failure
- `[@metadata][_index]` — preserve original names

### Check Migration Status
```bash
curl -s http://localhost:9200/_cat/indices | grep -E "product|semantic|legacy"
echo "---"
curl -s http://localhost:9201/_cat/indices | grep -E "product|semantic|legacy"
```
**Say:** "Data migrated with zero downtime"

---

## PHASE 3: CUTOVER (12 min)

### Dual-Write Pattern Diagram
```
PHASE 1: ES only
PHASE 2: Logstash backfills (demo running now)
PHASE 3: App writes to BOTH (dual-write)
PHASE 4: Verify queries match
PHASE 5: Switch to OS, rollback if needed
PHASE 6: Decommission ES
```
**Say:** "Each phase is reversible — rollback is a CLI command"

### Query Both Clusters
```bash
# ES
curl -s 'http://localhost:9200/product_embeddings/_search' | jq '.hits.total'

# OS  
curl -s 'http://localhost:9201/product_embeddings/_search' | jq '.hits.total'
```
**Say:** "Compare results before cutover — catch regressions early"

### Dashboards
```bash
open http://localhost:5601
```
**Show in browser:**
- Index Management → product_embeddings
- Verify knn_vector mapping
- Check document count

---

## PHASE 4: PRODUCTION (Migration Assistant)

### Kind Cluster Status
```bash
kubectl get pods -n ma | grep -E "migration-console|elasticsearch|opensearch"
```

### Workflow Status
```bash
kubectl -n ma exec migration-console-0 -- bash -c "workflow status"
```

---

## Q&A ANSWERS (Copy/Paste Ready)

**Q: How long for large clusters?**
```
A: ~1000 docs/sec per worker
   1B docs = 11 days with 100 workers
   Metadata: 5-15 min
   Backfill: scales linearly
```

**Q: dense_vector → knn_vector?**
```
A: Fully automatic in Migration Assistant
   - es2os detects it
   - MA applies during metadata phase  
   - Zero manual work
```

**Q: Can we run this now?**
```
A: Yes! Repo: https://github.com/Sagar2366/es2os

docker compose up -d
./es2os report --file testdata/es7_full_cluster.json
```

**Q: What if cluster fails mid-migration?**
```
A: Dual-write pattern keeps ES running
   - Rollback = flip connection string
   - Data already in ES
   - Zero data loss
```

---

## DEMO TROUBLESHOOTING

| Problem | Fix |
|---------|-----|
| Dashboards "unhealthy" | Wait 2-3 min, it's normal startup |
| Logstash shows errors | Check network: `docker network ls` |
| ES returns 401 | SearchGuard auth issue, try `curl -u admin:admin` |
| Query results differ | Expected for knn_vector (algorithm difference) |
| Kind cluster slow | Normal — building images, grab ☕ |

---

## TIME BUDGET

| Phase | Time | Commands |
|-------|------|----------|
| Analysis | 8 min | Report → Transform → HTML |
| Transform | 10 min | Show configs + status |
| Cutover | 12 min | Dual-write diagram + queries |
| Closing | 10 min | Q&A |

**If behind on time:** Skip Kind demo, focus on Docker Compose (faster)

---

## BACKUP COMMANDS (If things go wrong)

```bash
# Reset everything
docker compose down -v
docker compose up -d
sleep 60

# Rebuild es2os
go clean -modcache
rm go.sum
go mod tidy
go build -o es2os .

# Reload data
./load-sample-data.sh

# Restart Logstash
docker restart logstash-migration
```

---

## LINK TO SEND ATTENDEES

```
GitHub: https://github.com/Sagar2366/es2os
Docs: https://github.com/Sagar2366/es2os#readme
Issue Tracker: Report bugs if you try it!

Run this locally:
  git clone https://github.com/Sagar2366/es2os.git
  cd es2os
  ./es2os report --file testdata/es7_full_cluster.json
```

---

**Print this page. Read it before going on stage. You've got this! 🚀**

