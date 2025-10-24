# Configuration Changes for Fly.io Deployment

This document details all changes made to the original PokeAPI codebase to enable deployment on Fly.io with PostgreSQL and Redis.

## Overview

**Files Modified:**
1. `Dockerfile` - Updated base image and added Fly.io optimizations
2. `.dockerignore` - Enabled CSV data inclusion
3. `config/fly.py` - Created new Django settings file for Fly.io
4. `fly.toml` - Created Fly.io deployment configuration

**Files Created:**
- `config/fly.py` - Fly.io-specific Django settings
- `fly.toml` - Fly.io deployment configuration
- `verify_redis.sh` - Redis verification script
- `scripts/fly-build-db.sh` - Database build helper
- `scripts/fly-deploy.sh` - Deployment helper

---

## Detailed Changes

### 1. Dockerfile Modifications

**File:** `Dockerfile`

**Original Version:**
```dockerfile
ARG PYTHON_VERSION=3.10-slim-buster

FROM python:${PYTHON_VERSION}

ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

RUN mkdir -p /code

WORKDIR /code

COPY requirements.txt /tmp/requirements.txt

RUN set -ex && \
    pip install --upgrade pip && \
    pip install -r /tmp/requirements.txt && \
    rm -rf /root/.cache/

COPY . /code/

# RUN python manage.py collectstatic --noinput

EXPOSE 8000

# replace demo.wsgi with <project_name>.wsgi
# CMD ["/bin/bash", "-c", "python manage.py migrate ; gunicorn --bind :8000 --workers 1 demo.wsgi"]
CMD ["gunicorn", "--bind", ":8000", "--workers", "2", "demo.wsgi"]
```

**Updated Version:**
```dockerfile
ARG PYTHON_VERSION=3.10-slim-bookworm

FROM python:${PYTHON_VERSION}

ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Install system dependencies
RUN apt-get update && apt-get install -y \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /code

WORKDIR /code

COPY requirements.txt /tmp/requirements.txt

RUN set -ex && \
    pip install --upgrade pip && \
    pip install -r /tmp/requirements.txt && \
    rm -rf /root/.cache/

COPY . /code/

# Create a non-root user for fly.io
RUN useradd -m -u 1000 pokeapi && chown -R pokeapi:pokeapi /code
USER pokeapi

EXPOSE 8000

# Gunicorn will be started by fly.io using the processes in fly.toml
CMD ["gunicorn", "--bind", ":8000", "--workers", "2", "config.wsgi:application"]
```

**Changes Explained:**

1. **Base Image Update:**
   - Changed from `3.10-slim-buster` to `3.10-slim-bookworm`
   - Reason: Debian Buster reached end-of-life; Bookworm is the latest stable release

2. **PostgreSQL Client:**
   - Added `postgresql-client` installation
   - Reason: Needed for database operations and migrations

3. **Non-Root User:**
   - Created `pokeapi` user with UID 1000
   - Set proper file ownership
   - Switched to non-root user
   - Reason: Security best practice for Fly.io deployments

4. **Fixed WSGI Path:**
   - Changed from `demo.wsgi` to `config.wsgi:application`
   - Reason: Correct path for PokeAPI's WSGI configuration

---

### 2. .dockerignore Modifications

**File:** `.dockerignore`

**Original Line 29:**
```
data/v2/csv
```

**Updated Line 29:**
```
# data/v2/csv - NEEDED for database build!
```

**Change Explained:**
- **Commented out** the exclusion of `data/v2/csv`
- Reason: CSV files (35MB) contain all Pokemon data needed for database population
- Impact: Docker image size increased from ~240MB to ~315MB, but database can be built

---

### 3. New Django Settings for Fly.io

**File:** `config/fly.py` (NEW FILE)

```python
# Fly.io settings
import os
from .settings import *

# Database configuration for Fly.io
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql_psycopg2",
        "NAME": os.environ.get("POSTGRES_DB", "pokeapi"),
        "USER": os.environ.get("POSTGRES_USER", "ash"),
        "PASSWORD": os.environ.get("POSTGRES_PASSWORD", "pokemon"),
        "HOST": os.environ.get("POSTGRES_HOST", "db"),
        "PORT": os.environ.get("POSTGRES_PORT", 5432),
    }
}

# Redis caching with Upstash
CACHES = {
    "default": {
        "BACKEND": "django_redis.cache.RedisCache",
        "LOCATION": os.environ.get("REDIS_CONNECTION_STRING", "redis://cache:6379/1"),
        "OPTIONS": {
            "CLIENT_CLASS": "django_redis.client.DefaultClient",
        },
    }
}

# Production settings
DEBUG = False
ALLOWED_HOSTS = ["*"]  # Fly.io handles routing
```

**Purpose:**
- Separate configuration for Fly.io deployment
- Uses environment variables for database and Redis connections
- Inherits base settings from `config/settings.py`
- Production-ready with DEBUG=False

**Key Features:**
1. **PostgreSQL Configuration:**
   - Reads credentials from environment variables
   - Supports Fly.io's internal networking

2. **Redis Integration:**
   - Configured for Upstash Redis
   - Falls back to local Redis if not configured
   - Uses django-redis for connection pooling

3. **Security:**
   - DEBUG disabled
   - ALLOWED_HOSTS set to accept all (Fly.io handles routing)

---

### 4. Fly.io Deployment Configuration

**File:** `fly.toml` (NEW FILE)

```toml
# fly.toml app configuration file

app = "nynohu-api-poke"
primary_region = "nrt"

# Build configuration
[build]

[deploy]
  # Run migrations before deploying new version
  release_command = "python manage.py migrate --settings=config.fly"

[env]
  # Django settings
  DJANGO_SETTINGS_MODULE = "config.fly"
  PORT = "8000"

# HTTP service
[[services]]
  internal_port = 8000
  protocol = "tcp"
  auto_stop_machines = false
  auto_start_machines = true
  min_machines_running = 1

  [[services.ports]]
    port = 80
    handlers = ["http"]
    force_https = true

  [[services.ports]]
    port = 443
    handlers = ["tls", "http"]

  # Health check configuration
  [services.concurrency]
    type = "connections"
    hard_limit = 1000
    soft_limit = 800

  [[services.tcp_checks]]
    grace_period = "30s"
    interval = "15s"
    restart_limit = 0
    timeout = "5s"

# VM resources
[[vm]]
  memory = '1gb'
  cpu_kind = 'shared'
  cpus = 1
```

**Configuration Explained:**

1. **App Settings:**
   - `app`: Unique application name on Fly.io
   - `primary_region`: Deployment region (Tokyo/nrt)

2. **Build Section:**
   - Empty - uses Dockerfile automatically

3. **Deploy Section:**
   - `release_command`: Runs migrations before each deployment
   - Ensures database schema is always up-to-date

4. **Environment Variables:**
   - `DJANGO_SETTINGS_MODULE`: Points to Fly.io settings
   - `PORT`: Application port (8000)

5. **Service Configuration:**
   - `internal_port`: App listens on 8000
   - Auto-scaling: Keeps minimum 1 machine running
   - HTTP/HTTPS: Ports 80 and 443 exposed
   - `force_https`: Automatically redirects HTTP to HTTPS

6. **Health Checks:**
   - TCP check: Ensures port 8000 is responsive
   - Graceful startup: 30-second grace period
   - Regular checks: Every 15 seconds

7. **Resources:**
   - Memory: 1GB (can be scaled down to 256MB for free tier)
   - CPU: 1 shared CPU

---

## Environment Variables Required

### Set via Fly.io Secrets

These are sensitive values that should be set as secrets:

```bash
# PostgreSQL Connection
POSTGRES_HOST=your-app-db.internal
POSTGRES_DB=postgres
POSTGRES_USER=postgres
POSTGRES_PASSWORD=<generated-by-postgres-create>
POSTGRES_PORT=5432
DATABASE_URL=postgres://postgres:<password>@your-app-db.internal:5432/postgres

# Redis Connection
REDIS_CONNECTION_STRING=redis://default:<password>@fly-your-app-redis.upstash.io:6379
```

### Set in fly.toml

These are non-sensitive configuration values:

```toml
[env]
  DJANGO_SETTINGS_MODULE = "config.fly"
  PORT = "8000"
```

---

## Helper Scripts Created

### 1. Redis Verification Script

**File:** `verify_redis.sh`

**Purpose:** Quickly verify Redis integration is working

**Usage:**
```bash
chmod +x verify_redis.sh
./verify_redis.sh
```

### 2. Database Build Script

**File:** `scripts/fly-build-db.sh`

**Purpose:** Automate Pokemon data population after deployment

**Usage:**
```bash
chmod +x scripts/fly-build-db.sh
./scripts/fly-build-db.sh your-app-name
```

### 3. Deployment Helper

**File:** `scripts/fly-deploy.sh`

**Purpose:** Interactive deployment script with validations

**Usage:**
```bash
chmod +x scripts/fly-deploy.sh
./scripts/fly-deploy.sh
```

---

## Comparison: Original vs Fly.io Setup

### Original Docker Compose Setup

**Services:**
- PostgreSQL (local container)
- Redis (local container)
- Nginx (reverse proxy)
- Hasura GraphQL Engine
- Django App

**Configuration:**
- `config/docker-compose.py` - Settings for Docker Compose
- `docker-compose.yml` - Service orchestration
- Local networking between containers

### Fly.io Setup

**Services:**
- PostgreSQL (Fly.io managed)
- Redis (Upstash managed)
- Django App (Fly.io VM)

**Configuration:**
- `config/fly.py` - Settings for Fly.io
- `fly.toml` - Deployment configuration
- Internet-accessible endpoints
- Internal networking via `.internal` domains

**Key Differences:**

| Aspect | Docker Compose | Fly.io |
|--------|---------------|--------|
| Database | Local container | Managed service |
| Redis | Local container | Upstash Redis |
| Networking | Internal bridge network | Internal DNS + public endpoints |
| Scalability | Manual | Auto-scaling available |
| SSL/HTTPS | Manual (Nginx) | Automatic |
| Cost | Infrastructure costs | Pay-per-use |
| Maintenance | Self-managed | Managed platform |

---

## Migration Path from Docker Compose

If you have an existing Docker Compose setup and want to migrate to Fly.io:

1. **Export existing database:**
   ```bash
   docker-compose exec db pg_dump -U ash pokeapi > backup.sql
   ```

2. **Deploy to Fly.io** (follow main deployment guide)

3. **Import database:**
   ```bash
   cat backup.sql | flyctl postgres connect -a your-app-db
   ```

4. **Update DNS** to point to Fly.io app

---

## No Changes Required

The following files work without modification:

- ✅ `requirements.txt` - All dependencies compatible
- ✅ `config/settings.py` - Base settings inherited
- ✅ `config/wsgi.py` - WSGI configuration works as-is
- ✅ `pokemon_v2/` - API code unchanged
- ✅ `data/v2/csv/` - Pokemon data files unchanged
- ✅ `data/v2/build.py` - Database build script unchanged

---

## Testing Configuration Changes Locally

Before deploying, you can test the Fly.io configuration locally:

```bash
# 1. Build Docker image
docker build -t pokeapi-fly .

# 2. Run with Fly.io settings (requires local PostgreSQL and Redis)
docker run -p 8000:8000 \
  -e DJANGO_SETTINGS_MODULE=config.fly \
  -e POSTGRES_HOST=host.docker.internal \
  -e POSTGRES_DB=pokeapi \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=password \
  -e REDIS_CONNECTION_STRING=redis://localhost:6379 \
  pokeapi-fly
```

---

## Rollback Procedure

If you need to rollback changes:

### Restore Original Dockerfile
```bash
git checkout Dockerfile
```

### Restore Original .dockerignore
```bash
git checkout .dockerignore
```

### Use Original Settings
```bash
# Set environment to use docker-compose settings
export DJANGO_SETTINGS_MODULE=config.docker-compose
```

### Remove Fly.io Files
```bash
rm fly.toml config/fly.py
rm -rf scripts/
rm verify_redis.sh
```

---

## Summary of Changes

**Total Files Modified:** 2
- `Dockerfile` - Updated for Fly.io compatibility
- `.dockerignore` - Enabled CSV data inclusion

**Total Files Created:** 5
- `config/fly.py` - Fly.io Django settings
- `fly.toml` - Fly.io deployment config
- `verify_redis.sh` - Redis verification
- `scripts/fly-build-db.sh` - Database builder
- `scripts/fly-deploy.sh` - Deployment helper

**No Breaking Changes:**
- Original Docker Compose setup still works
- All changes are additive or Fly.io-specific
- Can run both configurations side-by-side

**Compatibility:**
- ✅ Python 3.10
- ✅ Django 3.2.25
- ✅ PostgreSQL 17
- ✅ Redis 7.x
- ✅ All existing dependencies
