# Quick Start: Deploy PokeAPI to Fly.io

Minimal steps to deploy PokeAPI with PostgreSQL and Redis on Fly.io's free tier.

## Prerequisites

- Fly.io account (free tier)
- Fly CLI installed and authenticated

```bash
# Install flyctl
brew install flyctl  # macOS
# or visit: https://fly.io/docs/hands-on/install-flyctl/

# Login
flyctl auth login
```

---

## 5-Minute Deployment

### Step 1: Set Up Environment

```bash
# Copy environment template
cp .env.example .env

# Edit .env with your app details
nano .env  # or use your preferred editor
```

**Required in .env:**
- `FLYIO_APP_NAME=my-pokeapi`
- Other values will be filled after creating resources

Also edit `fly.toml` line 1:
```toml
app = "my-pokeapi"  # Change to match your FLYIO_APP_NAME
```

### Step 2: Create & Deploy

```bash
# Create app
flyctl apps create my-pokeapi

# Create PostgreSQL (save the password!)
flyctl postgres create --name my-pokeapi-db --region nrt \
  --initial-cluster-size 1 --vm-size shared-cpu-1x --volume-size 10

# Set database secrets (use password from above)
flyctl secrets set \
  POSTGRES_HOST=my-pokeapi-db.internal \
  POSTGRES_DB=postgres \
  POSTGRES_USER=postgres \
  POSTGRES_PASSWORD=<YOUR_PASSWORD> \
  POSTGRES_PORT=5432 \
  --app my-pokeapi

# Create Redis (save the URL!)
flyctl redis create --name my-pokeapi-redis --region nrt \
  --no-replicas --enable-eviction

# Set Redis secret (use URL from above)
flyctl secrets set \
  REDIS_CONNECTION_STRING="<REDIS_URL>" \
  --app my-pokeapi

# Deploy
flyctl deploy --local-only --app my-pokeapi
```

### Step 3: Populate Database

**Option A: Using Helper Script (Recommended)**
```bash
# Uses app name from .env
./scripts/fly-build-db.sh
```

**Option B: Manual Command**
```bash
flyctl ssh console --app my-pokeapi --command \
  "python manage.py shell --settings=config.fly" <<'EOF'
from data.v2.build import build_all
build_all()
EOF
```

Wait 10-30 minutes for completion.

### Step 4: Test

```bash
curl https://my-pokeapi.fly.dev/api/v2/pokemon/1/
```

---

## What You Get

✅ **API:** https://my-pokeapi.fly.dev/
✅ **Database:** 1,328 Pokemon with full data (including Legends Z-A)
✅ **Caching:** Redis for fast responses
✅ **Environment:** Secure .env configuration
✅ **Cost:** $0-2/month on free tier

---

## Helper Scripts

All scripts load configuration from `.env`:

```bash
# Build database with new Pokemon
./scripts/fly-build-db.sh

# Verify Redis caching
./scripts/verify_redis.sh

# Deploy assistant (interactive)
./scripts/fly-deploy.sh
```

See [ENVIRONMENT_SETUP.md](./ENVIRONMENT_SETUP.md) for .env configuration details.

---

## Useful Commands

```bash
# View logs
flyctl logs --app my-pokeapi

# Check status
flyctl status --app my-pokeapi

# Restart app
flyctl apps restart my-pokeapi

# SSH into app
flyctl ssh console --app my-pokeapi
```

---

## Troubleshooting

**Deployment fails?**
```bash
# Check you're in the project directory
cd /path/to/pokeapi

# Verify fly.toml exists
ls fly.toml
```

**Can't connect to database?**
```bash
# List secrets to verify they're set
flyctl secrets list --app my-pokeapi

# Check database is running
flyctl status --app my-pokeapi-db
```

**Redis not working?**
```bash
# Verify Redis is running
flyctl redis status my-pokeapi-redis

# Test from app
flyctl ssh console --app my-pokeapi --command \
  'python -c "import os; os.environ[\"DJANGO_SETTINGS_MODULE\"]=\"config.fly\"; \
  import django; django.setup(); from django.core.cache import cache; \
  cache.set(\"test\", \"OK\", 60); print(cache.get(\"test\"))"'
```

---

## Next Steps

📖 **Full Documentation:**
- [Deployment Guide](./DEPLOYMENT_GUIDE.md) - Complete instructions
- [Configuration Changes](./CONFIGURATION_CHANGES.md) - What was modified
- [Redis Integration](./REDIS_INTEGRATION.md) - Cache details

🔧 **Optional Enhancements:**
- Set up custom domain
- Enable advanced health checks
- Configure automated backups
- Scale resources as needed

---

## Support

- Fly.io Docs: https://fly.io/docs/
- PokeAPI Repo: https://github.com/PokeAPI/pokeapi
- Issues: Check logs first with `flyctl logs --app my-pokeapi`
