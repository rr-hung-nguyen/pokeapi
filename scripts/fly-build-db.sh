#!/bin/bash
# Script to build the Pokemon database on Fly.io after deployment
# Location: scripts/fly-build-db.sh
# Usage: ./scripts/fly-build-db.sh [app-name]
# If app-name is not provided, it will read from .env file

set -e

# Load environment variables from .env file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
fi

# Use argument if provided, otherwise use environment variable
if [ -n "$1" ]; then
    APP_NAME=$1
elif [ -n "$FLYIO_APP_NAME" ]; then
    APP_NAME=$FLYIO_APP_NAME
    echo "Using app name from .env: $APP_NAME"
else
    echo "Usage: $0 <app-name>"
    echo "Example: $0 my-pokeapi"
    echo ""
    echo "Or create a .env file with FLYIO_APP_NAME variable"
    exit 1
fi

echo "Building Pokemon database for app: $APP_NAME"
echo "This will take 10-30 minutes depending on your VM size..."
echo ""

flyctl ssh console --app "$APP_NAME" --command "echo 'from data.v2.build import build_all; build_all()' | python manage.py shell --settings=config.docker-compose"

echo ""
echo "Database build complete!"
echo "Test your API at: https://$APP_NAME.fly.dev/api/v2/pokemon/1/"
