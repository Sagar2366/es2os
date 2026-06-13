# es2os — OpenSearchCon India 2026 Demo

**The Leapfrog Migration Playbook: Escaping Proprietary Search Without Breaking Production**

Live migration demo: Elasticsearch 7.17 → OpenSearch 2.19 with zero downtime.

## Quick Start

```bash
# Start the full stack (ES 7.17 + OpenSearch 2.19 + Logstash + Dashboards)
docker compose up -d

# Wait ~60s for services to be healthy, then load sample data
bash load-sample-data.sh

# Watch the migration happen
docker logs -f logstash-migration

# Verify data landed on OpenSearch
curl http://localhost:9201/_cat/indices?v

# Open OpenSearch Dashboards
open http://localhost:5601
```

## What's Running

| Service | Port | Purpose |
|---------|------|---------|
| ES 7.17.27 (source) | :9200 | Your "stuck" Elasticsearch cluster |
| OpenSearch 2.19 (target) | :9201 | Where data is migrating to |
| Logstash | — | Migrates data (scroll + bulk) |
| OpenSearch Dashboards | :5601 | Visual verification |

## Demo Flow (for the talk)

1. **Show source has data:** `curl http://localhost:9200/_cat/indices?v`
2. **Show the mapping issue:** `curl http://localhost:9200/product_embeddings/_mapping | jq '.product_embeddings.mappings.properties.product_vector'`
3. **Show migration is happening:** `curl http://localhost:9201/_cat/indices?v`
4. **Write NEW data to source:** `curl -X POST http://localhost:9200/product_embeddings/_doc/live_demo ...`
5. **Show it appeared on target:** `curl http://localhost:9201/product_embeddings/_doc/live_demo`
6. **Open Dashboards:** `open http://localhost:5601`

## Key Transformation: dense_vector → knn_vector

```
ES 7.17 (source):              OpenSearch 2.19 (target):
type: dense_vector             type: knn_vector
dims: 128                      dimension: 128
similarity: cosine             method.space_type: cosinesimil
                               method.engine: nmslib
```

This is the #1 issue that blocks teams from migrating vector search workloads.

## Talk Materials

See `opensearchcon-india-2026/` for:
- Complete talk guide
- Cheat sheet (print this!)
- Setup verification script
- Discussion notes

## Speakers

- **Sagar Utekar** — CrowdStrike
- **Sakshi Nasha** — Software Engineer & Open Source Contributor

## License

Apache-2.0
