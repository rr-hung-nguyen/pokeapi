#!/bin/bash
# Quick deployment script for Fly.io
# Location: scripts/fly-deploy.sh
# This script helps automate the deployment process

set -e

echo "PokeAPI Fly.io Deployment Helper"
echo "================================="
echo ""

# Check if flyctl is installed
if ! command -v flyctl &> /dev/null; then
    echo "Error: flyctl is not installed."
    echo "Install it from: https://fly.io/docs/hands-on/install-flyctl/"
    exit 1
fi

# Check if user is logged in
if ! flyctl auth whoami &> /dev/null; then
    echo "You are not logged in to Fly.io. Logging in..."
    flyctl auth login
fi

# Get app name from fly.toml or ask user
if [ -f "fly.toml" ]; then
    CURRENT_APP=$(grep "^app = " fly.toml | cut -d'"' -f2)
    if [ "$CURRENT_APP" == "your-pokeapi-app-name" ]; then
        echo "Please edit fly.toml and change the app name from 'your-pokeapi-app-name' to your desired app name."
        read -p "Enter your app name: " APP_NAME
        sed -i.bak "s/your-pokeapi-app-name/$APP_NAME/" fly.toml
        echo "Updated fly.toml with app name: $APP_NAME"
    else
        APP_NAME=$CURRENT_APP
        echo "Using app name from fly.toml: $APP_NAME"
    fi
else
    echo "Error: fly.toml not found in current directory"
    exit 1
fi

echo ""
echo "Deployment Steps:"
echo "1. Create/verify app exists"
echo "2. Deploy the application"
echo ""
read -p "Do you want to proceed? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# Check if app exists, create if not
if ! flyctl apps list | grep -q "$APP_NAME"; then
    echo "App '$APP_NAME' doesn't exist. Creating..."
    flyctl apps create "$APP_NAME"
else
    echo "App '$APP_NAME' already exists."
fi

echo ""
echo "Deploying application..."
flyctl deploy --app "$APP_NAME"

echo ""
echo "================================="
echo "Deployment complete!"
echo ""
echo "Next steps:"
echo "1. Set up PostgreSQL database (if not done yet):"
echo "   flyctl postgres create --name ${APP_NAME}-db"
echo "   flyctl postgres attach ${APP_NAME}-db --app $APP_NAME"
echo ""
echo "2. Set required environment variables:"
echo "   flyctl secrets set POSTGRES_HOST=${APP_NAME}-db.internal --app $APP_NAME"
echo "   flyctl secrets set POSTGRES_DB=pokeapi --app $APP_NAME"
echo "   flyctl secrets set POSTGRES_USER=postgres --app $APP_NAME"
echo "   flyctl secrets set POSTGRES_PASSWORD=<your-password> --app $APP_NAME"
echo ""
echo "3. Build the database with Pokemon data:"
echo "   ./scripts/fly-build-db.sh $APP_NAME"
echo ""
echo "4. Visit your API:"
echo "   https://$APP_NAME.fly.dev/api/v2/"
echo ""
echo "For full instructions, see FLY_DEPLOYMENT.md"
