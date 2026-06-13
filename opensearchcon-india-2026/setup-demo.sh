#!/bin/bash
# OpenSearchCon India 2026 - Complete Demo Setup Script
# Run this ONCE before the talk to verify everything is ready

set -e

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  OpenSearchCon India 2026 - Demo Verification Script     ║"
echo "║  The Leapfrog Migration Playbook                          ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_command() {
  if command -v $1 &> /dev/null; then
    echo -e "${GREEN}✓${NC} $1 found"
    return 0
  else
    echo -e "${RED}✗${NC} $1 NOT FOUND"
    return 1
  fi
}

check_docker_service() {
  if docker ps --format "{{.Names}}" | grep -q "^$1$"; then
    status=$(docker ps --format "{{.Status}}" --filter "name=^$1$" | grep -oE "Up|Exited")
    if [ "$status" = "Up" ]; then
      echo -e "${GREEN}✓${NC} $1 running"
      return 0
    else
      echo -e "${RED}✗${NC} $1 not running"
      return 1
    fi
  else
    echo -e "${RED}✗${NC} $1 not found"
    return 1
  fi
}

echo "═══ Prerequisites ═══"
check_command docker || exit 1
check_command docker-compose || exit 1
check_command go || exit 1
check_command curl || exit 1
check_command jq || exit 1

echo ""
echo "═══ Docker Services ═══"

# Check if es2os directory exists
if [ ! -d "$HOME/Desktop/es2os" ]; then
  echo -e "${YELLOW}ℹ${NC} es2os not found at ~/Desktop/es2os"
  echo "   Cloning from GitHub..."
  cd ~/Desktop
  git clone https://github.com/Sagar2366/es2os.git || exit 1
fi

cd ~/Desktop/es2os

# Check if docker-compose is up
if docker ps | grep -q es-source; then
  echo -e "${GREEN}✓${NC} Docker Compose running"
  
  check_docker_service es-source
  check_docker_service os-target
  check_docker_service os-dashboards
  check_docker_service logstash-migration
else
  echo -e "${YELLOW}ℹ${NC} Docker Compose not running, starting..."
  docker compose up -d
  sleep 60
  echo -e "${GREEN}✓${NC} Docker Compose started (check again in 30 sec)"
fi

echo ""
echo "═══ ES & OpenSearch Health ═══"

# Check ES connectivity
if curl -s http://localhost:9200 | jq .version.number &>/dev/null; then
  ES_VERSION=$(curl -s http://localhost:9200 | jq -r .version.number)
  echo -e "${GREEN}✓${NC} Elasticsearch $ES_VERSION"
else
  echo -e "${RED}✗${NC} Elasticsearch not responding"
fi

# Check OS connectivity
if curl -s http://localhost:9201 | jq .version.number &>/dev/null; then
  OS_VERSION=$(curl -s http://localhost:9201 | jq -r .version.number)
  echo -e "${GREEN}✓${NC} OpenSearch $OS_VERSION"
else
  echo -e "${RED}✗${NC} OpenSearch not responding"
fi

echo ""
echo "═══ es2os Binary ═══"

if [ -f "es2os" ]; then
  VERSION=$(./es2os version 2>&1 | grep -oE "v[0-9]+\.[0-9]+\.[0-9]+" || echo "unknown")
  echo -e "${GREEN}✓${NC} es2os binary ready ($VERSION)"
else
  echo -e "${YELLOW}ℹ${NC} es2os binary not found, building..."
  go clean -modcache
  rm -f go.sum
  go mod tidy
  go build -o es2os .
  echo -e "${GREEN}✓${NC} es2os built successfully"
fi

echo ""
echo "═══ Sample Data ═══"

# Check if data is loaded
ES_INDEX_COUNT=$(curl -s http://localhost:9200/_cat/indices | grep -E "product|semantic|legacy|audit|logs" | wc -l)
if [ "$ES_INDEX_COUNT" -gt 0 ]; then
  echo -e "${GREEN}✓${NC} Sample data already loaded ($ES_INDEX_COUNT indices)"
else
  echo -e "${YELLOW}ℹ${NC} Sample data not found, loading..."
  if [ -f "load-sample-data.sh" ]; then
    bash load-sample-data.sh
    echo -e "${GREEN}✓${NC} Sample data loaded"
  else
    echo -e "${RED}✗${NC} load-sample-data.sh not found"
  fi
fi

echo ""
echo "═══ Test Runs ═══"

# Test es2os report
if ./es2os report --file testdata/es7_full_cluster.json &>/dev/null; then
  echo -e "${GREEN}✓${NC} es2os report working"
else
  echo -e "${RED}✗${NC} es2os report failed"
fi

# Test es2os transform
if ./es2os transform --file testdata/es7_full_cluster.json &>/dev/null; then
  echo -e "${GREEN}✓${NC} es2os transform working"
else
  echo -e "${RED}✗${NC} es2os transform failed"
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                   ✓ READY FOR DEMO                       ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo "  1. Open a new terminal for logs: docker logs -f logstash-migration"
echo "  2. Keep this terminal open for running commands"
echo "  3. Reference TALK_CHEAT_SHEET.md for commands"
echo "  4. Good luck! 🚀"
echo ""
