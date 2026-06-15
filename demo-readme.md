# OpenSearchCon 2026: ES to OS Migration Demo



Run all commands from the final demo folder:



```bash

cd /Users/sagarutekar/Desktop/es2os/demo/es2os



```



---



## Part 1: Setup & Prerequisites



### 1. Initialize Cluster



For a fresh cluster (deletes existing cluster and reinstalls all components):



```bash

./demo-live.sh reset



```



To reuse a healthy existing cluster without deleting it:



```bash

./demo-live.sh setup



```



### 2. Verify Connectivity



Ensure main pods are ready and Migration Assistant connects to both clusters:



```bash

./demo-live.sh verify



```



*Goal: Look for `SOURCE CLUSTER Successfully connected` and `TARGET CLUSTER Successfully connected`.*



### 3. Deploy Observability & Core Components



```bash

# Install Grafana dashboard and metrics exporter

./demo-live.sh grafana



# Deploy the cutover demo app

./demo-live.sh app deploy



# Point the app to the Elasticsearch source first

./demo-live.sh app source



# Deploy the data browser UI

./demo-live.sh browser deploy



```



### 4. Background Port Forwards (Run in Separate Terminals)



```bash

kubectl --context kind-opensearchcon-2026 -n ma port-forward svc/kube-prometheus-stack-grafana 3000:80

kubectl --context kind-opensearchcon-2026 -n ma port-forward svc/search-cutover-gateway 8090:8090

kubectl --context kind-opensearchcon-2026 -n ma port-forward svc/migration-data-browser 8091:8091



```



### 5. Access UI Dashboards



* **Grafana:** http://localhost:3000 *(Credentials: `admin` / `prom-operator`)*

* **Cutover App:** http://localhost:8090

* **Data Browser:** http://localhost:8091



---



## Live Demo Sequence



### Verification Checks



Prove the environment is healthy and print live component versions on stage:



```bash

./demo-live.sh verify

./demo-live.sh versions



```



### Part 2 | Demo 1: Seed Data & Metadata Transformation



Seeds Elasticsearch with 10,000 orders and 1,000 vectors. Shows transforming ES `dense_vector` into OS `knn_vector`.



* **Talking Point:** *"Before we move data, we need the target cluster to understand the shape of that data."*



```bash

DEMO_ORDERS=10000 DEMO_VECTORS=1000 DEMO_LIVE_WRITES=100 ./demo-live.sh demo 1



```



### Part 3 | Demo 2: Snapshot & Historical Backfill



Creates LocalStack S3 bucket for archive storage. Migrates historical data into OpenSearch. Track progress using the Grafana dashboard.



```bash

./demo-live.sh demo 2



```



### Part 4 | Demo 3: Live Sync, Replay, & Diff



Adds 100 live writes to Elasticsearch, replays them to catch up OpenSearch, and validates data parity.



```bash

DEMO_LIVE_WRITES=100 ./demo-live.sh demo 3



```



*Goal: Look for `DIFF RESULT: PASS`.*



### Part 5 | Demo 4: Traffic Cutover



Switches client app routing from Elasticsearch to OpenSearch target.



* **Talking Point:** *"The client URL does not change. Only the backend route changes. Cutover is routing, not data movement."*



```bash

./demo-live.sh app target

./demo-live.sh demo cutover



```



### Part 6 | Demo 5: Fault Tolerance & Rollback



Demonstrates that Elasticsearch still exists for rollback if needed.



```bash

./demo-live.sh app source



```
