#!/bin/bash
# Load sample data into ES 7.17 source cluster
# Run AFTER: docker compose up -d (wait for health checks)

ES_URL="http://localhost:9200"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "⏳ Waiting for Elasticsearch..."
until curl -s "$ES_URL/_cluster/health" | grep -qE '"status":"(green|yellow)"'; do
  sleep 2
done
ES_VERSION=$(curl -s $ES_URL | python3 -c "import sys,json; print(json.load(sys.stdin)['version']['number'])" 2>/dev/null || echo "unknown")
echo -e "${GREEN}✅ Elasticsearch $ES_VERSION is ready${NC}"

echo ""
echo "⏳ Waiting for OpenSearch..."
until curl -s "http://localhost:9201/_cluster/health" | grep -qE '"status":"(green|yellow)"'; do
  sleep 2
done
OS_VERSION=$(curl -s http://localhost:9201 | python3 -c "import sys,json; print(json.load(sys.stdin)['version']['number'])" 2>/dev/null || echo "unknown")
echo -e "${GREEN}✅ OpenSearch $OS_VERSION is ready${NC}"

echo ""
echo "📦 Creating indices with sample data on ES source..."
echo ""

# 1. product_embeddings — dense_vector (THE HEADLINE TRANSFORMATION)
echo -n "  product_embeddings (dense_vector + knn)... "
curl -s -X PUT "$ES_URL/product_embeddings" -H 'Content-Type: application/json' -d '{
  "settings": {
    "index": {
      "number_of_shards": 1,
      "number_of_replicas": 0,
      "knn": true
    }
  },
  "mappings": {
    "properties": {
      "title": { "type": "text" },
      "description": { "type": "text" },
      "product_vector": {
        "type": "dense_vector",
        "dims": 128,
        "index": true,
        "similarity": "cosine"
      },
      "category": { "type": "keyword" },
      "price": { "type": "float" },
      "created_at": { "type": "date" }
    }
  }
}' > /dev/null 2>&1
echo -e "${GREEN}✓${NC}"

# Insert sample products with vectors
for i in $(seq 1 10); do
  VECTOR=$(python3 -c "import random; print(','.join([str(round(random.uniform(-1,1),4)) for _ in range(128)]))")
  curl -s -X POST "$ES_URL/product_embeddings/_doc/$i" -H 'Content-Type: application/json' -d "{
    \"title\": \"Product $i - Smart Device\",
    \"description\": \"High quality product with AI-powered features\",
    \"product_vector\": [$VECTOR],
    \"category\": \"electronics\",
    \"price\": $((RANDOM % 500 + 50)).99,
    \"created_at\": \"2024-0$((i % 9 + 1))-15\"
  }" > /dev/null 2>&1
done
echo "    → 10 docs with 128-dim vectors inserted"

# 2. semantic_search — another vector index with dot_product
echo -n "  semantic_search (dense_vector, dot_product)... "
curl -s -X PUT "$ES_URL/semantic_search" -H 'Content-Type: application/json' -d '{
  "settings": { "index": { "number_of_shards": 1, "number_of_replicas": 0, "knn": true } },
  "mappings": {
    "properties": {
      "content": { "type": "text" },
      "content_embedding": {
        "type": "dense_vector",
        "dims": 256,
        "index": true,
        "similarity": "dot_product"
      },
      "source": { "type": "keyword" },
      "timestamp": { "type": "date" }
    }
  }
}' > /dev/null 2>&1
echo -e "${GREEN}✓${NC}"

for i in $(seq 1 5); do
  VECTOR=$(python3 -c "import random; v=[random.gauss(0,1) for _ in range(256)]; norm=sum(x*x for x in v)**0.5; print(','.join([str(round(x/norm,4)) for x in v]))")
  curl -s -X POST "$ES_URL/semantic_search/_doc/$i" -H 'Content-Type: application/json' -d "{
    \"content\": \"Document $i about search technology and AI\",
    \"content_embedding\": [$VECTOR],
    \"source\": \"wiki\",
    \"timestamp\": \"2024-06-0$i\"
  }" > /dev/null 2>&1
done
echo "    → 5 docs with 256-dim vectors inserted"

# 3. audit_logs — _source disabled
echo -n "  audit_logs (_source disabled)... "
curl -s -X PUT "$ES_URL/audit_logs" -H 'Content-Type: application/json' -d '{
  "settings": { "index": { "number_of_shards": 1, "number_of_replicas": 0 } },
  "mappings": {
    "_source": { "enabled": false },
    "properties": {
      "timestamp": { "type": "date" },
      "user_id": { "type": "keyword" },
      "action": { "type": "keyword" },
      "resource": { "type": "text" },
      "ip_address": { "type": "ip" }
    }
  }
}' > /dev/null 2>&1
echo -e "${GREEN}✓${NC}"

for i in $(seq 1 20); do
  curl -s -X POST "$ES_URL/audit_logs/_doc/$i" -H 'Content-Type: application/json' -d "{
    \"timestamp\": \"2024-06-01T10:$((i%60)):00Z\",
    \"user_id\": \"user_$((RANDOM % 100))\",
    \"action\": \"$(echo login logout search update delete | tr ' ' '\n' | sort -R | head -1)\",
    \"resource\": \"/api/v1/resource/$i\",
    \"ip_address\": \"10.0.$((RANDOM%255)).$((RANDOM%255))\"
  }" > /dev/null 2>&1
done
echo "    → 20 audit log docs inserted"

# 4. user_sessions — normal index (clean migration)
echo -n "  user_sessions (clean index)... "
curl -s -X PUT "$ES_URL/user_sessions" -H 'Content-Type: application/json' -d '{
  "settings": { "index": { "number_of_shards": 1, "number_of_replicas": 0 } },
  "mappings": {
    "properties": {
      "user_id": { "type": "keyword" },
      "session_start": { "type": "date" },
      "session_end": { "type": "date" },
      "pages_viewed": { "type": "integer" },
      "device": { "type": "keyword" },
      "country": { "type": "keyword" }
    }
  }
}' > /dev/null 2>&1
echo -e "${GREEN}✓${NC}"

for i in $(seq 1 15); do
  curl -s -X POST "$ES_URL/user_sessions/_doc/$i" -H 'Content-Type: application/json' -d "{
    \"user_id\": \"usr_$((RANDOM % 500))\",
    \"session_start\": \"2024-06-01T0$((i%9+1)):00:00Z\",
    \"session_end\": \"2024-06-01T0$((i%9+2)):30:00Z\",
    \"pages_viewed\": $((RANDOM % 50 + 1)),
    \"device\": \"$(echo mobile desktop tablet | tr ' ' '\n' | sort -R | head -1)\",
    \"country\": \"$(echo IN US UK DE JP | tr ' ' '\n' | sort -R | head -1)\"
  }" > /dev/null 2>&1
done
echo "    → 15 session docs inserted"

# 5-6. Log indices (clean, time-series style)
for month in 01 02; do
  echo -n "  logs_2024_${month} (clean logs)... "
  curl -s -X PUT "$ES_URL/logs_2024_${month}" -H 'Content-Type: application/json' -d '{
    "settings": { "index": { "number_of_shards": 1, "number_of_replicas": 0 } },
    "mappings": {
      "properties": {
        "timestamp": { "type": "date" },
        "level": { "type": "keyword" },
        "message": { "type": "text" },
        "service": { "type": "keyword" },
        "trace_id": { "type": "keyword" }
      }
    }
  }' > /dev/null 2>&1
  echo -e "${GREEN}✓${NC}"

  for i in $(seq 1 10); do
    curl -s -X POST "$ES_URL/logs_2024_${month}/_doc/$i" -H 'Content-Type: application/json' -d "{
      \"timestamp\": \"2024-${month}-$((i%28+1))T12:00:00Z\",
      \"level\": \"$(echo INFO WARN ERROR | tr ' ' '\n' | sort -R | head -1)\",
      \"message\": \"Request processed for endpoint /api/v1/data\",
      \"service\": \"$(echo api-gateway auth-service data-service | tr ' ' '\n' | sort -R | head -1)\",
      \"trace_id\": \"trace-$(cat /dev/urandom | LC_ALL=C tr -dc 'a-f0-9' | head -c 8)\"
    }" > /dev/null 2>&1
  done
  echo "    → 10 log docs inserted"
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Show summary
echo "📊 Source cluster (ES $ES_VERSION) — indices:"
curl -s "$ES_URL/_cat/indices?v&h=index,docs.count,store.size" | grep -v "^\." | sort
echo ""

echo -e "${YELLOW}⏳ Logstash will now pick up these indices and migrate to OpenSearch...${NC}"
echo "   Watch progress: docker logs -f logstash-migration"
echo ""
echo "   After ~30 seconds, check target:"
echo "   curl http://localhost:9201/_cat/indices?v"
echo ""

# Wait and check if migration started
echo "⏳ Waiting 30s for Logstash to migrate..."
sleep 30

echo ""
echo "📊 Target cluster (OS $OS_VERSION) — indices:"
curl -s "http://localhost:9201/_cat/indices?v&h=index,docs.count,store.size" 2>/dev/null | grep -v "^\." | sort

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Demo data loaded and migration in progress!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Next steps:"
echo "  1. Verify migration: curl http://localhost:9201/_cat/indices?v"
echo "  2. Check mapping:    curl http://localhost:9201/product_embeddings/_mapping | python3 -m json.tool"
echo "  3. Open Dashboards:  open http://localhost:5601"
echo "  4. Test live write:  curl -X POST http://localhost:9200/product_embeddings/_doc/live1 -H 'Content-Type: application/json' -d '{\"title\":\"LIVE during migration!\",\"price\":99.99}'"
echo ""
