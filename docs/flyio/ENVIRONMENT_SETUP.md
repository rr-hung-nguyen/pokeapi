# Environment Configuration Guide

This guide explains how to set up environment variables for your PokeAPI deployment on macOS with zsh.

## Overview

Sensitive data like app names, URLs, passwords, and API keys are stored in environment files instead of being hardcoded in scripts. This approach:

- Keeps secrets out of version control
- Makes it easy to switch between environments
- Prevents accidental exposure of credentials
- Simplifies configuration management

## Quick Setup

### 1. Create Your Environment File

Copy the example environment file:

```bash
cp .env.example .env
```

### 2. Edit Your Environment File

Open `.env` in your favorite editor and fill in your actual values:

```bash
nano .env
# or
code .env
# or
vim .env
```

Update these values:
- `FLYIO_APP_NAME`: Your fly.io app name
- `FLYIO_APP_URL`: Your app's URL
- `POSTGRES_PASSWORD`: Your database password
- `REDIS_CONNECTION_STRING`: Your Redis connection string

### 3. Verify Configuration

Check that your .env file is loaded correctly:

```bash
source .env
echo "App: $FLYIO_APP_NAME"
echo "URL: $FLYIO_APP_URL"
```

## Environment Variables Reference

### Fly.io Configuration

| Variable | Description | Example |
|----------|-------------|---------|
| `FLYIO_APP_NAME` | Your fly.io application name | `nynohu-api-poke` |
| `FLYIO_REGION` | Deployment region | `nrt` (Tokyo) |
| `FLYIO_APP_URL` | Your app's public URL | `https://nynohu-api-poke.fly.dev` |

### Database Configuration

| Variable | Description | Example |
|----------|-------------|---------|
| `FLYIO_DB_NAME` | PostgreSQL database app name | `nynohu-api-poke-db` |
| `POSTGRES_HOST` | Database host | `nynohu-api-poke-db.internal` |
| `POSTGRES_DB` | Database name | `pokeapi` |
| `POSTGRES_USER` | Database user | `postgres` |
| `POSTGRES_PASSWORD` | Database password | `your-secure-password` |
| `POSTGRES_PORT` | Database port | `5432` |

### Redis Configuration

| Variable | Description | Example |
|----------|-------------|---------|
| `FLYIO_REDIS_NAME` | Redis instance name | `nynohu-api-poke-redis` |
| `REDIS_CONNECTION_STRING` | Full Redis connection URL | `redis://default:token@host:6379` |

### Django Configuration

| Variable | Description | Example |
|----------|-------------|---------|
| `DJANGO_SETTINGS_MODULE` | Django settings module | `config.fly` |
| `DEBUG` | Debug mode (use False in production) | `False` |

## Using Scripts with Environment Variables

All helper scripts now automatically load environment variables from `.env`:

### Verify Redis Integration

```bash
./scripts/verify_redis.sh
```

This script will:
- Load variables from `.env`
- Use `$FLYIO_APP_NAME`, `$FLYIO_APP_URL`, and `$FLYIO_REDIS_NAME`
- Display which values it's using

### Build Database

```bash
# Option 1: Use .env file
./scripts/fly-build-db.sh

# Option 2: Override with command line argument
./scripts/fly-build-db.sh my-other-app-name
```

### Deploy Application

```bash
./scripts/fly-deploy.sh
```

Reads app name from `fly.toml` (which can reference environment variables).

## macOS zsh Configuration (Optional)

If you want environment variables to be available in all terminal sessions:

### Option 1: Load on Shell Startup (Project-Specific)

Add to your `~/.zshrc`:

```bash
# PokeAPI Environment (only if in project directory)
if [ -f "$HOME/workspace/pokeapi/.env" ]; then
    source "$HOME/workspace/pokeapi/.env"
fi
```

**Pros**: Variables always available
**Cons**: Loads for every new terminal, even outside the project

### Option 2: Create an Alias (Recommended)

Add to your `~/.zshrc`:

```bash
# PokeAPI Environment Loader
alias load-pokeapi='cd ~/workspace/pokeapi && source .env && echo "PokeAPI environment loaded"'
```

Then use:

```bash
load-pokeapi
```

**Pros**: Only loads when needed
**Cons**: Must remember to run the alias

### Option 3: Use Automatically When Entering Directory

Add to your `~/.zshrc`:

```bash
# Auto-load .env when entering project directory
autoload -U add-zsh-hook
load-project-env() {
    if [ -f .env ]; then
        source .env
        echo "✓ Loaded .env"
    fi
}
add-zsh-hook chpwd load-project-env
```

**Pros**: Automatic, no manual steps
**Cons**: Will load any .env file in any directory you enter

### Apply zsh Configuration

After editing `~/.zshrc`, reload your configuration:

```bash
source ~/.zshrc
```

## Security Best Practices

### DO ✓

- Keep `.env` in `.gitignore` (already configured)
- Use strong, unique passwords
- Rotate credentials regularly
- Share `.env.example` (without real values)
- Use `flyctl secrets` for production values

### DON'T ✗

- Commit `.env` to version control
- Share `.env` file directly
- Use the same password across environments
- Store credentials in plaintext outside `.env`
- Email or message credentials

## Retrieving Credentials

### Get Database Password

```bash
flyctl postgres list
flyctl postgres attach <db-name> --app <app-name>
```

Or retrieve from fly.io dashboard.

### Get Redis Connection String

```bash
flyctl redis status <redis-name>
```

Or from your Upstash dashboard.

### List All Secrets

```bash
flyctl secrets list --app <app-name>
```

Note: This shows secret names but not their values (for security).

## Troubleshooting

### Script Can't Find .env File

**Error**: `Warning: .env file not found. Please create one from .env.example`

**Solution**:
```bash
# Make sure you're in the project root
cd ~/workspace/pokeapi

# Copy example file
cp .env.example .env

# Edit with your values
nano .env
```

### Variables Not Loading

**Check file location**:
```bash
ls -la .env
```

**Check file permissions**:
```bash
chmod 600 .env  # Owner read/write only
```

**Manual load test**:
```bash
source .env
echo $FLYIO_APP_NAME
```

### Wrong Values Being Used

**Check for conflicts**:
```bash
# See what's currently set
env | grep FLYIO

# Unset if needed
unset FLYIO_APP_NAME

# Reload
source .env
```

## Multiple Environments

If you manage multiple deployments:

### Create Environment-Specific Files

```bash
.env.production
.env.staging
.env.development
```

### Use Symlinks

```bash
# Link to production
ln -sf .env.production .env

# Switch to staging
ln -sf .env.staging .env
```

### Or Use Scripts

```bash
# scripts/use-env.sh
#!/bin/bash
if [ "$1" == "production" ]; then
    cp .env.production .env
elif [ "$1" == "staging" ]; then
    cp .env.staging .env
else
    echo "Usage: $0 [production|staging]"
fi
```

## Example Workflow

```bash
# 1. Clone repository
git clone <repo-url>
cd pokeapi

# 2. Set up environment
cp .env.example .env
nano .env  # Fill in your values

# 3. Run scripts
./scripts/verify_redis.sh
./scripts/fly-build-db.sh

# 4. Optional: Add to zsh
echo 'alias load-pokeapi="cd ~/workspace/pokeapi && source .env"' >> ~/.zshrc
source ~/.zshrc
```

## Additional Resources

- [Fly.io Secrets Management](https://fly.io/docs/reference/secrets/)
- [12-Factor App Configuration](https://12factor.net/config)
- [zsh Configuration Guide](https://zsh.sourceforge.io/Guide/)

## Getting Help

If environment variables aren't working:

1. Check `.env` exists and has correct values
2. Verify file permissions (`chmod 600 .env`)
3. Try manual source: `source .env`
4. Check script is loading from correct path
5. Review script output for "Loaded environment from .env file" message
