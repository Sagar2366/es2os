#!/bin/bash
# Load sample data into the ES 7.17 source cluster
# Run after: docker compose up -d && sleep 10

ES_URL="http://localhost:9200"

echo "⏳ Waiting for Elasticsearch..."
until curl -s "$ES_URL" > /dev/null 2>&1; do sleep 2; done
echo "✅ Elasticsearch is up: $(curl -s $ES_URL | jq -r '.version.number')"

echo ""
echo "📦 Creating indices with sample data..."

# 1. product_embeddings — dense_vector (THE HEADLINE)
curl -s -X PUT "$ES_URL/product_embeddings" -H 'Content-Type: application/json' -d '{
  "settings": { "index": { "number_of_shards": 1, "knn": true } },
  "mappings": {
    "properties": {
      "title": { "type": "text" },
      "description": { "type": "text" },
      "product_vector": { "type": "dense_vector", "dims": 768, "index": true, "similarity": "cosine" },
      "category": { "type": "keyword" },
      "price": { "type": "float" },
      "created_at": { "type": "date" }
    }
  }
}' | jq -r '.acknowledged // .error.reason'
echo "  → product_embeddings (dense_vector, knn=true)"

# 2. semantic_search — another vector index
curl -s -X PUT "$ES_URL/semantic_search" -H 'Content-Type: application/json' -d '{
  "settings": { "index": { "number_of_shards": 1, "knn": true } },
  "mappings": {
    "properties": {
      "content": { "type": "text" },
      "content_embedding": { "type": "dense_vector", "dims": 1536, "index": true, "similarity": "dot_product" },
      "metadata": { "type": "object", "properties": { "source": { "type": "keyword" }, "timestamp": { "type": "date" } } }
    }
  }
}' | jq -r '.acknowledged // .error.reason'
echo "  → semantic_search (dense_vector, dot_product)"

# 3. audit_logs — _source disabled
curl -s -X PUT "$ES_URL/audit_logs" -H 'Content-Type: application/json' -d '{
  "settings": { "index": { "number_of_shards": 1, "soft_deletes.enabled": true } },
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
}' | jq -r '.acknowledged // .error.reason'
echo "  → audit_logs (_source disabled, soft_deletes)"

# 4. multilingual_docs — custom analyzers (ICU + Kuromoji won't work without plugins, but mapping is enough)
curl -s -X PUT "$ES_URL/multilingual_docs" -H 'Content-Type: application/json' -d '{
  "settings": { "index": { "number_of_shards": 1 } },
  "mappings": {
    "properties": {
      "title_en": { "type": "text", "analyzer": "standard" },
      "content": { "type": "text" },
      "tags": { "type": "keyword" },
      "locale": { "type": "keyword" }
    }
  }
}' | jq -r '.acknowledged // .error.reason'
echo "  → multilingual_docs"

# 5-6. Clean log indices
for month in 01 02 03; do
  curl -s -X PUT "$ES_URL/logs_2024_${month}" -H 'Content-Type: application/json' -d '{
    "settings": { "index": { "number_of_shards": 1 } },
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
done
echo "  → logs_2024_01, logs_2024_02, logs_2024_03 (clean)"

# Insert some sample docs so it looks real
echo ""
echo "📝 Inserting sample documents..."

# Product with vector
curl -s -X POST "$ES_URL/product_embeddings/_doc/1" -H 'Content-Type: application/json' -d '{
  "title": "Wireless Noise-Cancelling Headphones",
  "description": "Premium ANC headphones with 30hr battery",
  "product_vector": ['"$(python3 -c "import random; print(','.join([str(round(random.uniform(-1,1),4)) for _ in range(768)]))")"'],
  "category": "electronics",
  "price": 299.99,
  "created_at": "2024-06-01"
}' > /dev/null 2>&1

# Audit log
curl -s -X POST "$ES_URL/audit_logs/_doc/1" -H 'Content-Type: application/json' -d '{
  "timestamp": "2024-06-01T10:30:00Z",
  "user_id": "usr_42",
  "action": "login",
  "resource": "/api/auth",
  "ip_address": "10.0.1.55"
}' > /dev/null 2>&1

# Some logs
for i in $(seq 1 5); do
  curl -s -X POST "$ES_URL/logs_2024_01/_doc/$i" -H 'Content-Type: application/json' -d "{
    \"timestamp\": \"2024-01-0${i}T12:00:00Z\",
    \"level\": \"INFO\",
    \"message\": \"Request processed successfully\",
    \"service\": \"api-gateway\",
    \"trace_id\": \"trace-$(uuidgen | head -c 8)\"
  }" > /dev/null 2>&1
done

echo "  → Sample docs inserted"

echo ""
echo "✅ Done! Source cluster ready."
echo ""
echo "Run:  ./es2os report --cluster http://localhost:9200 --target-version 2.19.5"
echo ""
