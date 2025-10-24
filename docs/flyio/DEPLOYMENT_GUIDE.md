# PokeAPI Deployment Guide for Fly.io

Complete guide for deploying PokeAPI to Fly.io with PostgreSQL and Redis caching.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Deployment](#quick-deployment)
- [Detailed Steps](#detailed-steps)
- [Post-Deployment](#post-deployment)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software
- **Fly.io CLI** - [Installation Guide](https://fly.io/docs/hands-on/install-flyctl/)
  ```bash
  # macOS
  brew install flyctl

  # Linux
  curl -L https://fly.io/install.sh | sh

  # Windows
  pwsh -Command "iwr https://fly.io/install.ps1 -useb | iex"
  ```

### Required Accounts
- **Fly.io Account** - Sign up at https://fly.io/app/sign-up
- Free tier includes:
  - 3 shared-cpu-1x VMs with 256MB RAM
  - 3GB persistent volume storage

### Authenticate with Fly.io
```bash
flyctl auth login
```

---

## Quick Deployment

For experienced users who want to deploy quickly:

```bash
# 1. Update configuration
# Edit fly.toml - change app name and region

# 2. Create app and database
flyctl apps create your-app-name
flyctl postgres create --name your-app-db --region nrt --initial-cluster-size 1 --vm-size shared-cpu-1x --volume-size 10

# 3. Set database credentials
flyctl secrets set \
  POSTGRES_HOST=your-app-db.internal \
  POSTGRES_DB=postgres \
  POSTGRES_USER=postgres \
  POSTGRES_PASSWORD=<from-postgres-create> \
  POSTGRES_PORT=5432 \
  DATABASE_URL=postgres://postgres:<password>@your-app-db.internal:5432/postgres \
  --app your-app-name

# 4. Create Redis
flyctl redis create --name your-app-redis --region nrt --no-replicas --enable-eviction

# 5. Set Redis connection
flyctl secrets set REDIS_CONNECTION_STRING=<redis-url> --app your-app-name

# 6. Deploy
flyctl deploy --local-only --app your-app-name

# 7. Build database
flyctl ssh console --app your-app-name --command \
  "python manage.py shell --settings=config.fly" <<'EOF'
from data.v2.build import build_all
build_all()
EOF
```

---

## Detailed Steps

### Step 1: Configure Application Name and Region

Edit `fly.toml` and update these values:

```toml
app = "your-app-name"  # Change to your desired app name (must be unique)
primary_region = "nrt"  # Change to your preferred region
```

**Available Regions:** Run `flyctl platform regions` to see all options
- `nrt` - Tokyo, Japan
- `iad` - Virginia, USA
- `lhr` - London, UK
- `fra` - Frankfurt, Germany
- `syd` - Sydney, Australia

### Step 2: Create the Application

```bash
flyctl apps create your-app-name
```

**Note:** Replace `your-app-name` with your actual app name throughout this guide.

### Step 3: Create PostgreSQL Database

```bash
flyctl postgres create \
  --name your-app-db \
  --region nrt \
  --initial-cluster-size 1 \
  --vm-size shared-cpu-1x \
  --volume-size 10
```

**Important:** Save the credentials displayed after creation:
```
Username:    postgres
Password:    <generated-password>
Hostname:    your-app-db.internal
```

### Step 4: Configure Database Connection

Set the database environment variables as secrets:

```bash
flyctl secrets set \
  POSTGRES_HOST=your-app-db.internal \
  POSTGRES_DB=postgres \
  POSTGRES_USER=postgres \
  POSTGRES_PASSWORD=<your-generated-password> \
  POSTGRES_PORT=5432 \
  --app your-app-name
```

Also set the DATABASE_URL for compatibility:

```bash
flyctl secrets set \
  DATABASE_URL=postgres://postgres:<password>@your-app-db.internal:5432/postgres \
  --app your-app-name
```

### Step 5: Create Redis Cache

```bash
flyctl redis create \
  --name your-app-redis \
  --region nrt \
  --no-replicas \
  --enable-eviction
```

**Save the Redis URL displayed:**
```
redis://default:<password>@fly-your-app-redis.upstash.io:6379
```

### Step 6: Configure Redis Connection

```bash
flyctl secrets set \
  REDIS_CONNECTION_STRING="redis://default:<password>@fly-your-app-redis.upstash.io:6379" \
  --app your-app-name
```

### Step 7: Deploy the Application

```bash
flyctl deploy --local-only --app your-app-name
```

**What happens during deployment:**
1. Docker image is built locally
2. Image is pushed to Fly.io registry
3. Migrations run automatically (via `release_command` in fly.toml)
4. Application starts on port 8000

**Expected duration:** 3-5 minutes

### Step 8: Populate Database with Pokemon Data

After successful deployment, populate the database:

```bash
flyctl ssh console --app your-app-name --command \
  "python manage.py shell --settings=config.fly" <<'EOF'
from data.v2.build import build_all
print('Starting Pokemon database build...')
build_all()
print('Build complete!')
EOF
```

**Expected duration:** 10-30 minutes
**Data imported:** 1,302 Pokemon with complete data

---

## Post-Deployment

### Verify Deployment

1. **Check app status:**
   ```bash
   flyctl status --app your-app-name
   ```

2. **Test API endpoint:**
   ```bash
   curl https://your-app-name.fly.dev/api/v2/pokemon/1/
   ```

3. **View logs:**
   ```bash
   flyctl logs --app your-app-name
   ```

### Access Your API

**Base URL:** `https://your-app-name.fly.dev/`

**Example Endpoints:**
- List Pokemon: `https://your-app-name.fly.dev/api/v2/pokemon/`
- Get Bulbasaur: `https://your-app-name.fly.dev/api/v2/pokemon/bulbasaur/`
- Get Pikachu: `https://your-app-name.fly.dev/api/v2/pokemon/pikachu/`
- List Abilities: `https://your-app-name.fly.dev/api/v2/ability/`
- List Moves: `https://your-app-name.fly.dev/api/v2/move/`

---

## Verification

### Verify Redis Integration

Run the verification script:
```bash
./verify_redis.sh
```

Or test manually:
```bash
# Test cache operations
flyctl ssh console --app your-app-name --command \
  'python -c "import os; os.environ[\"DJANGO_SETTINGS_MODULE\"]=\"config.fly\"; \
  import django; django.setup(); from django.core.cache import cache; \
  cache.set(\"test\", \"Works!\", 60); print(cache.get(\"test\"))"'

# Test response time improvement
for i in {1..3}; do
  echo "Request $i:"
  curl -s -o /dev/null -w "Time: %{time_total}s\n" \
    https://your-app-name.fly.dev/api/v2/pokemon/25/
done
```

### Verify Database

Check Pokemon count:
```bash
curl -s https://your-app-name.fly.dev/api/v2/pokemon/ | grep -o '"count":[0-9]*'
```

Expected: `"count":1302`

---

## Troubleshooting

### Deployment Issues

**Issue:** Build fails with "Dockerfile not found"
```bash
# Solution: Ensure you're in the project root directory
cd /path/to/pokeapi
flyctl deploy --local-only --app your-app-name
```

**Issue:** Database connection errors
```bash
# Solution: Verify database secrets are set
flyctl secrets list --app your-app-name

# Re-set if needed
flyctl secrets set POSTGRES_HOST=your-app-db.internal --app your-app-name
```

**Issue:** Redis connection errors
```bash
# Solution: Check Redis status
flyctl redis status your-app-redis

# Verify connection string
flyctl secrets list --app your-app-name | grep REDIS
```

### Performance Issues

**Issue:** Slow response times
```bash
# Solution: Verify Redis is caching
# Run 3 requests to same endpoint - should get faster
for i in {1..3}; do
  curl -s -o /dev/null -w "Request $i: %{time_total}s\n" \
    https://your-app-name.fly.dev/api/v2/pokemon/pikachu/
done
```

**Issue:** Database build fails
```bash
# Solution: Check available memory
flyctl status --app your-app-db

# If needed, check logs
flyctl logs --app your-app-name
```

### Common Commands

```bash
# Restart application
flyctl apps restart your-app-name

# View real-time logs
flyctl logs --app your-app-name

# SSH into application
flyctl ssh console --app your-app-name

# Check PostgreSQL status
flyctl status --app your-app-db

# Check Redis status
flyctl redis status your-app-redis

# Run Django management commands
flyctl ssh console --app your-app-name --command \
  "python manage.py <command> --settings=config.fly"
```

---

## Cost Breakdown

### Free Tier Usage
- **App VM:** 256MB RAM (1 of 3 free VMs)
- **PostgreSQL VM:** 256MB RAM (1 of 3 free VMs)
- **Redis:** Pay-as-you-go ($0.20 per 100K commands)

### Expected Monthly Costs
- **Development/Testing:** $0-2/month
- **Light Production:** $2-5/month
- **Heavy Production:** $10-30/month (depending on traffic)

### Scaling (Additional Costs)
```bash
# Increase app memory (costs money beyond free tier)
flyctl scale memory 512 --app your-app-name

# Add more instances (costs money)
flyctl scale count 2 --app your-app-name

# Increase database memory (costs money)
flyctl scale memory 1024 --app your-app-db
```

---

## Next Steps

1. **Set up custom domain** (optional)
   ```bash
   flyctl certs create your-domain.com --app your-app-name
   ```

2. **Enable HTTP health checks**
   - Uncomment the health check section in `fly.toml`
   - Redeploy: `flyctl deploy --app your-app-name`

3. **Set up monitoring**
   - Use Fly.io dashboard: https://fly.io/dashboard
   - View metrics, logs, and health status

4. **Configure backups**
   - PostgreSQL: Enable automated backups in Fly.io dashboard
   - Redis: Data is ephemeral (cache only)

5. **Review security**
   - Set strong `SECRET_KEY` if needed
   - Configure `ALLOWED_HOSTS` if desired
   - Enable HTTPS (already enabled by default)

---

## Additional Resources

- [Fly.io Documentation](https://fly.io/docs/)
- [PokeAPI Documentation](https://pokeapi.co/docs/v2)
- [Django Deployment Checklist](https://docs.djangoproject.com/en/3.2/howto/deployment/checklist/)
- [Configuration Changes Reference](./CONFIGURATION_CHANGES.md)
- [Redis Integration Details](./REDIS_INTEGRATION.md)

---

## Support

**Issues with this deployment?**
- Check the [Troubleshooting](#troubleshooting) section
- Review Fly.io logs: `flyctl logs --app your-app-name`
- Consult Fly.io community: https://community.fly.io/

**Issues with PokeAPI itself?**
- Original repository: https://github.com/PokeAPI/pokeapi
- Report issues: https://github.com/PokeAPI/pokeapi/issues
