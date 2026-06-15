
# OpenSearchCon India 2026 Demo

Live demo for **The Leapfrog Migration Playbook: Escaping Proprietary Search Without Breaking Production**.

This repository contains the stage-safe Kubernetes demo for migrating from Elasticsearch to OpenSearch using OpenSearch Migration Assistant concepts:

- Metadata migration and `dense_vector` to `knn_vector` transformation
- Snapshot/backfill story using in-cluster LocalStack/S3
- Live writes with Kafka-style capture/replay lane using Strimzi
- Comparative response diffing
- Client cutover and rollback using Kubernetes Service routing
- Grafana dashboards for migration visibility

The final demo path is Kubernetes only. Do not use the older Docker Compose/Kibana flow for the live session.

## Demo Folder

Run all commands from this folder:

```bash
cd /Users/sagarutekar/Desktop/es2os/demo/es2os
```

## Fresh Cluster Setup

```bash
./demo-live.sh setup
```

Creates the fresh kind Kubernetes cluster and installs the complete demo stack:

- Elasticsearch source
- OpenSearch target
- OpenSearch Migration Assistant
- Argo Workflows
- LocalStack/S3
- Strimzi/Kafka demo lane
- Grafana and demo metrics
- Cutover app
- Data browser

## Verify The Environment

```bash
./demo-live.sh verify
```

Confirms Migration Assistant is ready and can connect to both Elasticsearch and OpenSearch.

```bash
./demo-live.sh versions
```

Prints the actual Elasticsearch, OpenSearch, and Migration Assistant versions. Use this on stage instead of hardcoding versions.

## Prepare Visuals

```bash
./demo-live.sh grafana
```

Installs or refreshes the OpenSearchCon Grafana dashboard and demo metrics exporter.

```bash
./demo-live.sh app deploy
./demo-live.sh app source
```

Deploys the cutover app and starts it on the Elasticsearch source route.

```bash
./demo-live.sh browser deploy
```

Deploys the data browser UI for showing actual order and vector documents.

Open these port-forwards in separate terminals and keep them running:

```bash
kubectl --context kind-opensearchcon-2026 -n ma port-forward svc/kube-prometheus-stack-grafana 3000:80
```

```bash
kubectl --context kind-opensearchcon-2026 -n ma port-forward svc/search-cutover-gateway 8090:8090
```

```bash
kubectl --context kind-opensearchcon-2026 -n ma port-forward svc/migration-data-browser 8091:8091
```

Open:

```text
Grafana:      http://localhost:3000
Cutover app:  http://localhost:8090
Data browser: http://localhost:8091
```

Grafana login:
