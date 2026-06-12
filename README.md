# es2os

**Elasticsearch → OpenSearch mapping analyzer and transformer**

A CLI tool that scans Elasticsearch index mappings, identifies OpenSearch incompatibilities, and generates transformed mappings. Built for the [OpenSearchCon India 2026](https://opensearchcon.org/) talk: *"The Leapfrog Migration Playbook: Escaping Proprietary Search Without Breaking Production"*.

## Quick Start

```bash
# Install Go 1.22+ then:
go mod tidy
go build -o es2os .

# Run the full report (this is the demo command)
./es2os report --file testdata/es7_full_cluster.json
```

## Commands

```bash
# Scan: read mappings and show inventory
./es2os scan --file <mappings.json>

# Analyze: identify compatibility issues
./es2os analyze --file <mappings.json>

# Transform: generate OpenSearch-compatible mappings
./es2os transform --file <mappings.json>
./es2os transform --file <mappings.json> --output-file os-mappings.json

# Report: full pipeline in one shot (scan + analyze + transform + display)
./es2os report --file <mappings.json>
./es2os report --file <mappings.json> -o html --html-file report.html
```

## Global Flags

```
--file, -f           Path to ES mapping JSON file (required)
--source-version     Source ES version (default: "7.17")
--target-version     Target OS version (default: "2.19")
--output, -o         Output format: terminal | html (default: terminal)
--no-color           Disable colored output
--verbose, -v        Verbose details
```

## What It Detects

| Rule | Issue | Severity | Auto-Fix? |
|------|-------|----------|-----------|
| VEC001 | `dense_vector` → `knn_vector` | Critical | ✅ |
| VEC002 | Index-level `knn` setting (v3.3.1 bug) | Warning | ✅ |
| TYP001 | Multi-type index (ES 5.x) | Critical | ❌ |
| SRC001 | `_source: disabled` (empty docs risk) | Warning | ❌ |
| SET001 | `index.mapper.dynamic` (removed) | Warning | ✅ |
| SET002 | `index.merge.policy` (changed) | Info | ✅ |
| SET003 | `index.soft_deletes.enabled` (always on) | Warning | ✅ |
| ANZ001 | ICU analyzer plugin | Warning | ❌ |
| ANZ002 | Kuromoji analyzer plugin | Warning | ❌ |
| ANZ003 | Custom analysis config | Info | ❌ |
| ILM001 | ILM policy (→ ISM manual) | Critical | ❌ |
| DST001 | Data stream backing index | Critical | ❌ |

## Input Format

The tool accepts ES mapping JSON in multi-index format:

```json
{
  "index_name": {
    "mappings": {
      "properties": { ... }
    },
    "settings": {
      "index": { ... }
    }
  }
}
```

Export from your cluster:
```bash
# Export all mappings
curl -s localhost:9200/_mapping | jq . > my-cluster.json

# Export with settings (recommended)
curl -s localhost:9200/_settings | jq . > settings.json
# Then merge manually or use the cluster export format
```

## The Headline Transformation

**dense_vector → knn_vector** is not just a rename:

```
Elasticsearch 7.x:               OpenSearch 2.x:
{                                 {
  "type": "dense_vector",           "type": "knn_vector",
  "dims": 768,                      "dimension": 768,
  "similarity": "cosine"            "method": {
}                                     "name": "hnsw",
                                      "space_type": "cosinesimil",
                                      "engine": "nmslib",
                                      "parameters": {
                                        "ef_construction": 512,
                                        "m": 16
                                      }
                                    }
                                  }
```

## Demo (3 minutes on stage)

```bash
# Show the tool analyzing a realistic cluster export
./es2os report --file testdata/es7_full_cluster.json --source-version 7.17.27 --target-version 2.19.5

# Show the transformed output
./es2os transform --file testdata/es7_full_cluster.json | jq '.indices.product_embeddings.new_mapping'

# Generate HTML report to share with team
./es2os report --file testdata/es7_full_cluster.json -o html --html-file report.html && open report.html
```

## Architecture

```
es2os/
├── cmd/           # Cobra CLI commands
├── pkg/
│   ├── scanner/   # Read ES mapping JSON
│   ├── analyzer/  # 12 compatibility rules
│   ├── transformer/ # Generate OS-compatible output
│   └── reporter/  # Terminal (colored) + HTML output
└── testdata/      # Sample ES mapping files
```

Inspired by:
- [ingress2gateway](https://github.com/kubernetes-sigs/ingress2gateway) — K8s SIG migration tool
- [ing-switch](https://github.com/saiyam1814/ing-switch) — Universal ingress migration utility
- [OpenSearch Migration Assistant](https://github.com/opensearch-project/opensearch-migrations)

## License

Apache-2.0

## Authors

- Sagar Utekar ([@sutekar](https://github.com/sutekar)) — CrowdStrike
- Sakshi Nasha — Software Engineer & Open Source Contributor
