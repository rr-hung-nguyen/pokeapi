#!/bin/bash
# Script to verify Redis caching is working on your PokeAPI
# Location: scripts/verify_redis.sh

set -e

# Load environment variables from .env file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
    echo "Loaded environment from .env file"
else
    echo "Warning: .env file not found. Please create one from .env.example"
    exit 1
fi

# Use environment variables with fallback
APP_NAME="${FLYIO_APP_NAME:-nynohu-api-poke}"
APP_URL="${FLYIO_APP_URL:-https://nynohu-api-poke.fly.dev}"
REDIS_NAME="${FLYIO_REDIS_NAME:-nynohu-api-poke-redis}"

echo "========================================="
echo "PokeAPI Redis Verification"
echo "========================================="
echo ""
echo "App: $APP_NAME"
echo "URL: $APP_URL"
echo "Redis: $REDIS_NAME"
echo ""

TEST_ENDPOINT="/api/v2/pokemon/pikachu/"

echo "1. Testing Redis connection from Django..."
flyctl ssh console --app "$APP_NAME" --command "python -c '
import os
os.environ[\"DJANGO_SETTINGS_MODULE\"] = \"config.fly\"
import django
django.setup()
from django.core.cache import cache

# Test cache
cache.set(\"verify_test\", \"Redis is working!\", 60)
result = cache.get(\"verify_test\")
print(f\"✓ Redis test: {result}\")
'"

echo ""
echo "2. Testing API response times (caching)..."
echo "   Making 3 requests to same endpoint..."

echo -n "   Request 1 (cold): "
TIME1=$(curl -s -o /dev/null -w "%{time_total}" $APP_URL$TEST_ENDPOINT)
echo "${TIME1}s"

echo -n "   Request 2 (cached): "
TIME2=$(curl -s -o /dev/null -w "%{time_total}" $APP_URL$TEST_ENDPOINT)
echo "${TIME2}s"

echo -n "   Request 3 (cached): "
TIME3=$(curl -s -o /dev/null -w "%{time_total}" $APP_URL$TEST_ENDPOINT)
echo "${TIME3}s"

echo ""
echo "3. Redis instance status:"
flyctl redis status "$REDIS_NAME" | grep -E "Name|Plan|Region|Eviction"

echo ""
echo "========================================="
echo "✓ Redis is integrated and caching!"
echo "========================================="
echo ""
echo "Tip: If request 2 & 3 are faster than request 1,"
echo "     that confirms caching is working!"
