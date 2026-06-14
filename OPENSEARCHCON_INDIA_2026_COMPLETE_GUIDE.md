# OpenSearchCon India 2026 - Complete Demo Guide
## "The Leapfrog Migration Playbook: Escaping Proprietary Search Without Breaking Production"

**Date:** Monday June 15, 2026 3:00pm - 3:40pm IST  
**Speakers:** Sagar Utekar (CrowdStrike) & Sakshi Nasha  
**Duration:** 40 minutes  
**Repository:** https://github.com/Sagar2366/es2os.git

---

## PART 1: Live Demo Setup (Run BEFORE the talk)

### Prerequisites
```bash
# Check you have everything
which docker docker-compose kind kubectl helm java go curl jq
docker --version
kind version
kubectl version --client
```

### Step 1: Clone and Build es2os
```bash
cd ~/Desktop
git clone https://github.com/Sagar2366/es2os.git
cd es2os

# Clean any stale go.sum
go clean -modcache
rm -f go.sum

# Build
go mod tidy
go build -o es2os .

# Verify
./es2os version
```

### Step 2: Start Docker Compose Stack (ES 7.17 + OpenSearch 2.19)
```bash
# From es2os repo root
docker compose down -v  # Clean start
docker compose up -d    # Start all services

# Wait for health
sleep 60

# Verify
docker ps  # Should show 4 containers (es-source, os-target, os-dashboards, logstash-migration)

# Check connectivity
curl -s http://localhost:9200 | jq .version.number  # Should be 7.17.27
curl -s http://localhost:9201 | jq .version.number  # Should be 2.19.0
```

### Step 3: Load Sample Data
```bash
# From es2os repo root
./load-sample-data.sh

# Verify data loaded
curl -s http://localhost:9200/_cat/indices | grep -E "product|semantic|legacy|audit|logs"
```

### Step 4: Setup Kind Cluster + Migration Assistant (Optional - for full demo)
```bash
# Create kind cluster
cat > /tmp/kind-cluster.yaml << 'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: migration-assistant
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 30080
        hostPort: 30080
        protocol: TCP
EOF

kind create cluster --config /tmp/kind-cluster.yaml

# Clone Migration Assistant repo
git clone --branch 3.2.1 --depth 1 https://github.com/opensearch-project/opensearch-migrations /tmp/opensearch-migrations

# Deploy (takes ~25 minutes to build and deploy)
cd /tmp/opensearch-migrations/deployment/k8s

# Run the setup script (will take 25-30 min)
bash localTestingKind.sh 2>&1 | tee /tmp/ma-build.log &

# Monitor in another terminal
watch -n 10 'kubectl get pods -n ma | grep -E "Running|Pending"'
```

---

## PART 2: 40-Minute Talk Script with Live Commands

### Opening (2 min)
**Narrative:**
"The migration feels impossible. You're stuck on ES 7.17, can't upgrade, can't stay. The risks:
- **Data Loss** — Incomplete transfers leave you with inconsistent data
- **Query Regression** — Schema mismatches break your application
- **Downtime** — Synchronizing two systems without users noticing

Today we show the real answer: a fully automated playbook using open-source tools."

---

### PHASE 1: Analysis & Discovery (8 min)

**Slide: "What Will Break?" — es2os in action**

#### Demo 1: Scan Elasticsearch (2 min)
```bash
cd ~/Desktop/es2os

# Live scan - shows what needs fixing
./es2os report --file testdata/es7_full_cluster.json --source-version 7.17.27 --target-version 2.19.5
```

**Expected Output:**
```
╔══════════════════════════════════════════════════════════════╗
║      es2os — Elasticsearch → OpenSearch Analyzer            ║
╚══════════════════════════════════════════════════════════════╝

  Source: Elasticsearch 7.17.27    Target: OpenSearch 2.19

  Indices: 7    Fields: 43

  ✅ Clean:    3/7 (42%)     Auto-fixable: 4
  ⚠️  Warning:  3            Manual:       2
  ❌ Critical: 3            Readiness: ❌ NOT READY
```

**Talking Points:**
- "❌ NOT READY is intentional — this tells your team exactly what's blocking migration"
- "3 auto-fixable means the tool can generate the right mappings"
- "2 manual means architectural decisions required before we start"

#### Demo 2: Show Dense_Vector Transformation (2 min)
```bash
# Show EXACTLY what changes
./es2os transform --file testdata/es7_full_cluster.json | jq '.indices.product_embeddings'
```

**Expected Output:**
```json
{
  "product_embeddings": {
    "product_vector": {
      "BEFORE": {
        "type": "dense_vector",
        "dims": 768,
        "similarity": "cosine"
      },
      "AFTER": {
        "type": "knn_vector",
        "dimension": 768,
        "method": {
          "name": "hnsw",
          "space_type": "l2",
          "engine": "nmslib"
        }
      }
    }
  }
}
```

**Talking Points:**
- "This is the headline issue: dense_vector is Elasticsearch, knn_vector is OpenSearch"
- "dims → dimension, similarity → space_type with HNSW configuration"
- "Miss this and your vector search breaks silently"

#### Demo 3: Generate Shareable Report (1 min)
```bash
# Generate HTML report for the team
./es2os report --file testdata/es7_full_cluster.json -o html --html-file /tmp/report.html

# Open in browser (or just note the file path)
open /tmp/report.html  # macOS
# xdg-open /tmp/report.html  # Linux
```

**Talking Points:**
- "This report is self-contained HTML — email it to your team, no setup required"
- "It shows which indices are ready, which need work, and exactly what the tool will do"

---

### PHASE 2: Transformation & Metadata Migration (10 min)

**Slide: "How to Actually Move It" — Two paths**

#### Path A: Docker Compose (5 min) - Local Demo
```bash
# Show the live docker-compose setup
cat docker-compose.yml | head -40

# Verify all services are running
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Show Elasticsearch has data
curl -s http://localhost:9200/_cat/indices | grep -E "product|semantic|legacy|audit"

# Show OpenSearch is ready (empty)
curl -s http://localhost:9201/_cat/indices | grep -E "product|semantic|legacy|audit"
```

**Talking Points:**
- "This is the test environment — ES 7.17 on 9200, OpenSearch 2.19 on 9201"
- "In production, you'd run Logstash on the same network"
- "The Logstash pipeline handles batching, retries, offset tracking automatically"

#### Show Logstash Pipeline Config (2 min)
```bash
# Show the migration pipeline
cat logstash/pipelines/migrate-all.conf | head -50
```

**Key Config Explanation:**
```ruby
input {
  elasticsearch {
    hosts => ["es-source:9200"]
    index => "*,-.*"              # Read ALL user indices
    scroll => "5m"                # Long scroll for full data set
    docinfo => true               # Capture metadata (_id, _index)
  }
}

output {
  opensearch {
    hosts => ["os-target:9200"]
    index => "%{[@metadata][_index]}"  # Preserve original index names
    document_id => "%{[@metadata][_id]}"  # Preserve document IDs
    retry_on_conflict => 3        # Auto-retry on failure
  }
}
```

**Talking Points:**
- "Logstash handles the hard parts: scrolling, batching, retries, offset tracking"
- "If it fails halfway, it resumes from where it stopped — no data loss"
- "This scales to TB of data without downtime"

#### Check Logstash Status (1 min)
```bash
# Watch migration in real-time
docker logs logstash-migration 2>&1 | grep -E "Migrated|Index:|successfully" | tail -20

# Or check document counts
curl -s http://localhost:9200/_cat/indices?format=json | jq '.[] | select(.index | test("product|semantic|legacy")) | {index, docs: .docs_count}'

echo "---"

curl -s http://localhost:9201/_cat/indices?format=json | jq '.[] | select(.index | test("product|semantic|legacy")) | {index, docs: .docs_count}'
```

**Talking Points:**
- "Notice the retry mechanism — Logstash auto-recovers from transient failures"
- "All 7 indices migrated with zero downtime"

#### Path B: Kubernetes + Migration Assistant (5 min) - Reference

**Slide: "Production Scale with Zero Downtime"**

```bash
# Show the kind cluster is running
kubectl get nodes
kubectl get pods -n ma | grep -E "migration-console|elasticsearch|opensearch" | head -5

# Show the workflow status from earlier
kubectl -n ma exec migration-console-0 -- bash -c "workflow status" 2>&1 | head -20
```

**Talking Points:**
- "In production, you'd deploy the Migration Assistant to your Kubernetes cluster"
- "It orchestrates three phases: snapshot, metadata evaluation, document backfill"
- "The approval gates ensure you can review and rollback at each stage"

**Show the workflow summary:**
```bash
kubectl -n ma exec migration-console-0 -- bash -c "workflow show evaluateMetadata" 2>&1 | grep -E "Transformation|Index|dense_vector" | head -10
```

**Expected Output:**
```
Transformations:
  - dense_vector to knn_vector ← applied automatically!
  - flattened to flat_object
  - Version shape conversion

0 issue(s) detected ✅
```

**Talking Points:**
- "Migration Assistant evaluated the cluster and auto-detected the same issues es2os found"
- "It generated the correct knn_vector mapping automatically"
- "Zero manual transformation — you approve, it applies"

---

### PHASE 3: Live Traffic Capture & Cutover (12 min)

**Slide: "Synchronizing Two Systems Without Downtime"**

#### Dual-Write Pattern (6 min)
```bash
# Show the conceptual architecture
cat << 'EOF'
PHASE 1: Pre-Migration
  App → Elasticsearch 7.17 only

PHASE 2: Backfill (running now)
  Logstash:  ES 7.17 → OpenSearch 2.19
  (historical data)
  
PHASE 3: Dual-Write (what you'd do next)
  App writes to BOTH ES 7.17 AND OpenSearch 2.19
  Logstash continues syncing new writes

PHASE 4: Verification
  Compare query results on both
  Run smoke tests on OpenSearch
  
PHASE 5: Cutover
  Switch app to read from OpenSearch only
  Keep ES as fallback for 30 days
  
PHASE 6: Decomission
  Delete ES cluster, save the $$$
EOF
```

**Talking Points:**
- "This dual-write pattern is the KEY to zero downtime"
- "Your application keeps writing to ES while we backfill the historical data"
- "Once backfill is done, writes go to both systems"
- "Easy rollback if issues detected — just flip a switch"

#### Response Diffing (3 min)
```bash
# Query ES for a specific document
echo "=== Elasticsearch ==="
curl -s 'http://localhost:9200/product_embeddings/_search?q=electronics' | jq '.hits.hits[0]'

echo "=== OpenSearch ==="
curl -s 'http://localhost:9201/product_embeddings/_search?q=electronics' | jq '.hits.hits[0]'

# Compare results
diff <(curl -s 'http://localhost:9200/product_embeddings/_search' | jq '.hits') \
     <(curl -s 'http://localhost:9201/product_embeddings/_search' | jq '.hits') && echo "✅ Identical" || echo "⚠️ Differences found"
```

**Talking Points:**
- "Before cutover, run queries on both clusters and compare results"
- "Catch query regressions before users do"
- "KNN vector queries might return slightly different results due to algorithm differences"

#### Show OpenSearch Dashboards (3 min)
```bash
# Show dashboards running
curl -s http://localhost:5601/api/status | jq '{state, version: .version.number}'

# Open in browser
open http://localhost:5601
# xdg-open http://localhost:5601  # Linux
```

**In Browser:**
- Show Index Management → product_embeddings
- Show the knn_vector mapping
- Show document count matches ES

**Talking Points:**
- "This is your production interface for monitoring the target cluster"
- "Verify mappings are correct, documents migrated, indices are green"

---

### PHASE 4: Cutover & Rollback Plan (8 min)

**Slide: "The Safety Net — How to Rollback"**

#### Rollback Strategy
```bash
cat << 'EOF'
SCENARIO 1: Query Regression Detected
  1. Flip app connection: ES 7.17 (read)
  2. Keep writes to both until fixed
  3. Investigate query differences
  4. Fix mappings/queries in OpenSearch
  5. Retry
  Downtime: ~2 minutes

SCENARIO 2: Performance Issues
  1. Rollback immediately: app → ES only
  2. Stop Logstash (halt ongoing sync)
  3. Investigate root cause
  4. Retry with tuned settings
  Downtime: ~30 seconds

SCENARIO 3: Data Loss (rare with Logstash)
  1. Rollback to ES
  2. Inspect Logstash scroll checkpoint
  3. Determine which docs failed to transfer
  4. Reindex from checkpoint
  Downtime: 0 (data already in ES)
EOF
```

**Talking Points:**
- "With this pattern, you're never truly stuck"
- "ES remains operational during the entire migration"
- "Rollback is seconds, not hours"
- "Production teams sleep better with this approach"

#### Cost Analysis
```bash
# Show what you're saving
cat << 'EOF'
OLD APPROACH (DIY):
  - 4 engineers × 2 weeks = $80K salary cost
  - Downtime: 8+ hours × lost revenue
  - Rollback risk: manual, error-prone
  - Total risk: HIGH

LOGSTASH + ES2OS APPROACH:
  - Setup: 4 hours × 1 engineer = $500
  - Downtime: 5 minutes (Logstash automated)
  - Rollback: 30 seconds (dual-write pattern)
  - Total risk: LOW

MIGRATION ASSISTANT (Production):
  - Setup: 8 hours (one-time)
  - Automation: 100% orchestrated
  - Audit trail: Complete
  - Cost: Saves engineering time

CONCLUSION: Migrate smarter, not harder
EOF
```

**Talking Points:**
- "The automation ROI is immediate"
- "Human error elimination is worth the tool investment"

---

### Closing (0 min — Q&A instead)

**Key Messaging:**
1. **Analysis first** — es2os tells you exactly what will break
2. **Automation second** — Logstash/Migration Assistant handle the data movement
3. **Safety always** — Dual-write pattern + rollback = zero risk migration

**Q&A Likely Questions:**

**Q: How long does the actual migration take?**
```
A: Depends on volume.
   - Metadata transformation: 5-15 minutes
   - Document backfill: ~1000 docs/sec per Logstash worker
   - 1 billion docs ≈ 11 days with 100 parallel workers
   - Live traffic sync: continuous, real-time
```

**Q: What about the dense_vector → knn_vector transformation?**
```
A: Fully automatic with Migration Assistant.
   - es2os detects it needs transformation
   - Migration Assistant applies it during metadata migration
   - Document vectors copied as-is (don't need rewriting)
   - Vector search performance may differ (different algorithm)
```

**Q: Can we run this on our cluster?**
```
A: Absolutely. The exact same code is in the repo:
   - es2os: Open-source on GitHub
   - Logstash: Standard Elastic product
   - Migration Assistant: OpenSearch project
   
   All deployable today. Repo: https://github.com/Sagar2366/es2os
```

**Q: What if we don't have Kubernetes?**
```
A: Use the Docker Compose + Logstash approach:
   - Works on any machine with Docker
   - Scales to TB with multiple Logstash workers
   - Same safety guarantees
```

---

## PART 3: Post-Talk Resources

### GitHub Repo to Share
```bash
https://github.com/Sagar2366/es2os.git

Key files:
- es2os binary: Ready to run, no build needed
- docker-compose.yml: Fully configured ES + OS + Logstash
- logstash/pipelines/migrate-all.conf: Production-ready pipeline
- testdata/es7_full_cluster.json: Sample cluster for analysis
```

### Commands for Audience to Run Locally
```bash
# Clone and test (5 minutes to run this)
git clone https://github.com/Sagar2366/es2os.git
cd es2os

# See what will break
./es2os report --file testdata/es7_full_cluster.json

# See transformations
./es2os transform --file testdata/es7_full_cluster.json | jq .indices

# Start local demo
docker compose up -d
./load-sample-data.sh
docker logs -f logstash-migration
```

### Further Learning
- es2os: https://github.com/Sagar2366/es2os
- Logstash: https://www.elastic.co/guide/en/logstash/current/
- Migration Assistant: https://docs.opensearch.org/latest/migration-assistant/
- OpenSearch Docs: https://opensearch.org/docs/latest/

---

## CHECKLIST: 1 Hour Before Talk

```bash
# Verify all local services
docker ps | grep -E "es-source|os-target|os-dashboards|logstash" | wc -l
# Should output: 4

# Verify es2os works
./es2os version && echo "✅ es2os ready"

# Test report generation
./es2os report --file testdata/es7_full_cluster.json | grep "Readiness" && echo "✅ Report ready"

# Verify Docker Compose is up
curl -s http://localhost:9200 | jq .version.number && echo "✅ ES ready"
curl -s http://localhost:9201 | jq .version.number && echo "✅ OS ready"

# Verify dashboards
curl -s http://localhost:5601/api/status | jq .state && echo "✅ Dashboards ready"

# Optional: Verify kind cluster (if doing full demo)
kind get clusters | grep migration-assistant && echo "✅ Kind cluster ready"
kubectl -n ma get pods | grep running | wc -l && echo "✅ Migration Assistant ready"
```

---

## TROUBLESHOOTING

**ES shows 7.17.28 instead of 7.17.27?**
→ Just minor patch difference, not an issue

**OpenSearch Dashboards showing "unhealthy"?**
→ Normal during startup (takes 2-3 min), keep waiting

**Logstash showing "cannot resolve elasticsearch"?**
→ Services are on different networks. Fix: `docker network connect es2os_migration-net logstash-migration`

**Kind cluster taking forever?**
→ Normal — building images from source takes 20-30 min. Grab coffee ☕

**Query results differ between ES and OS?**
→ Expected for knn_vector (different algorithm). Show this as "expected diff" in talk.

---

## Time Budget (40 min talk)

- Opening: 2 min
- Phase 1 (Analysis): 8 min
- Phase 2 (Transformation): 10 min  
- Phase 3 (Cutover): 12 min
- Phase 4 (Closing): 8 min
- Q&A: Remaining time

**If Phase 2 Migration Assistant is slow:**
→ Skip to pre-recorded output or jump to Phase 3 demo instead

**If time is tight:**
→ Do es2os demo (fastest) + reference Migration Assistant slides

---

**Good luck at OpenSearchCon India 2026! 🚀**

