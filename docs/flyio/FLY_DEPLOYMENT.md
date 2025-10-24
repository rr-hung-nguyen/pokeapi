# PokeAPI Deployment Guide for Fly.io

This guide will walk you through deploying the PokeAPI project to Fly.io, including both the API and PostgreSQL database.

## Prerequisites

Before you begin, make sure you have:

1. **Fly.io CLI installed** - Install from https://fly.io/docs/hands-on/install-flyctl/
   ```bash
   # macOS
   brew install flyctl

   # Linux
   curl -L https://fly.io/install.sh | sh

   # Windows
   pwsh -Command "iwr https://fly.io/install.ps1 -useb | iex"
   ```

2. **Fly.io account** - Sign up at https://fly.io/app/sign-up (you mentioned you already have this)

3. **Authenticate with Fly.io**
   ```bash
   flyctl auth login
   ```

4. **Docker installed** (for local testing, optional)

## Step 1: Configure Your App

1. **Edit the `fly.toml` file** and update these values:
   - Change `app = "your-pokeapi-app-name"` to your desired app name (must be unique across Fly.io)
   - Change `primary_region = "sjc"` to your preferred region
     - Run `flyctl platform regions` to see all available regions
     - Common regions: `iad` (Virginia), `lax` (Los Angeles), `lhr` (London), `fra` (Frankfurt), `syd` (Sydney)

## Step 2: Create and Launch the App

1. **Initialize the app** (from the pokeapi directory):
   ```bash
   flyctl apps create your-pokeapi-app-name
   ```
   Or let fly.io create it during first deploy.

## Step 3: Set Up PostgreSQL Database

Fly.io offers managed PostgreSQL databases that work seamlessly with your apps.

1. **Create a Postgres cluster**:
   ```bash
   flyctl postgres create --name your-pokeapi-db
   ```

   During creation, you'll be asked:
   - **Region**: Choose the same region as your app (important for performance)
   - **VM size**: `shared-cpu-1x` with `256MB` RAM is fine for development/testing
   - **Volume size**: `10GB` is a good start (can be increased later)

2. **Attach the database to your app**:
   ```bash
   flyctl postgres attach your-pokeapi-db --app your-pokeapi-app-name
   ```

   This will automatically set the `DATABASE_URL` environment variable in your app.

3. **Set additional database environment variables**:
   The app needs specific environment variables. Get your database credentials:
   ```bash
   flyctl postgres connect --app your-pokeapi-db --command "echo \$DATABASE_URL"
   ```

   Then set them manually:
   ```bash
   # Extract values from DATABASE_URL and set them
   flyctl secrets set POSTGRES_HOST=your-pokeapi-db.internal --app your-pokeapi-app-name
   flyctl secrets set POSTGRES_DB=your_db_name --app your-pokeapi-app-name
   flyctl secrets set POSTGRES_USER=postgres --app your-pokeapi-app-name
   flyctl secrets set POSTGRES_PASSWORD=your_password --app your-pokeapi-app-name
   flyctl secrets set POSTGRES_PORT=5432 --app your-pokeapi-app-name
   ```

## Step 4: Set Up Redis Cache (Optional but Recommended)

For Redis caching, you have two options:

### Option A: Upstash Redis (Recommended - Free tier available)

1. **Create Upstash Redis** via Fly.io:
   ```bash
   flyctl redis create
   ```
   Follow prompts to create your Redis instance.

2. **Get the Redis URL and set it**:
   ```bash
   flyctl redis status <redis-name>
   # Copy the connection string
   flyctl secrets set REDIS_CONNECTION_STRING="redis://default:password@host:port" --app your-pokeapi-app-name
   ```

### Option B: Deploy Redis as a separate Fly.io app

If you prefer to manage your own Redis:
1. Create a separate Redis instance using Fly.io
2. Set the connection string appropriately

### Option C: Skip Redis (Not Recommended)

If you want to skip Redis for now, you'll need to modify `config/docker-compose.py` to use a dummy cache backend.

## Step 5: Deploy the Application

1. **Deploy to Fly.io**:
   ```bash
   flyctl deploy
   ```

   This will:
   - Build the Docker image
   - Push it to Fly.io's registry
   - Run migrations automatically (via release_command in fly.toml)
   - Start your app

2. **Monitor the deployment**:
   ```bash
   flyctl logs
   ```

## Step 6: Build the Database with Pokemon Data

After the first deployment, you need to populate the database with Pokemon data:

```bash
# Connect to your app and run the build script
flyctl ssh console --app your-pokeapi-app-name

# Once connected, run:
python manage.py shell --settings=config.docker-compose

# In the Python shell, run:
from data.v2.build import build_all
build_all()
exit()
```

Alternatively, use this one-liner:
```bash
flyctl ssh console --app your-pokeapi-app-name --command "echo 'from data.v2.build import build_all; build_all()' | python manage.py shell --settings=config.docker-compose"
```

**Note**: This process can take 10-30 minutes depending on the VM size. The database build imports all Pokemon data from CSV files.

## Step 7: Verify Deployment

1. **Open your app**:
   ```bash
   flyctl open
   ```

   Or visit: `https://your-pokeapi-app-name.fly.dev`

2. **Test the API**:
   ```bash
   curl https://your-pokeapi-app-name.fly.dev/api/v2/pokemon/1/
   curl https://your-pokeapi-app-name.fly.dev/api/v2/pokemon/bulbasaur/
   ```

3. **Check app status**:
   ```bash
   flyctl status --app your-pokeapi-app-name
   ```

## Useful Commands

### View logs
```bash
flyctl logs --app your-pokeapi-app-name
```

### SSH into your app
```bash
flyctl ssh console --app your-pokeapi-app-name
```

### Run Django management commands
```bash
flyctl ssh console --app your-pokeapi-app-name --command "python manage.py <command> --settings=config.docker-compose"
```

### Scale your app
```bash
# Increase VM memory
flyctl scale memory 2048 --app your-pokeapi-app-name

# Add more instances
flyctl scale count 2 --app your-pokeapi-app-name
```

### Update secrets
```bash
flyctl secrets set KEY=value --app your-pokeapi-app-name
```

### Restart your app
```bash
flyctl apps restart your-pokeapi-app-name
```

## Troubleshooting

### Database connection errors
- Make sure all `POSTGRES_*` environment variables are set correctly
- Check that the database is attached: `flyctl postgres list`
- Verify the database is running: `flyctl status --app your-pokeapi-db`

### Migration errors
- Run migrations manually: `flyctl ssh console --app your-pokeapi-app-name --command "python manage.py migrate --settings=config.docker-compose"`

### Out of memory errors during database build
- Scale up the VM: `flyctl scale memory 2048`
- Or do the build in stages by running specific build commands

### App not responding
- Check logs: `flyctl logs --app your-pokeapi-app-name`
- Check health checks in the Fly.io dashboard
- Restart the app: `flyctl apps restart your-pokeapi-app-name`

## Cost Estimates

Fly.io pricing (as of 2024):
- **Apps**: Free tier includes up to 3 shared-cpu VMs with 256MB RAM
- **Postgres**: Starts at ~$1.94/month for shared-cpu-1x with 256MB
- **Volumes**: ~$0.15/GB per month
- **Bandwidth**: 100GB free, then $0.02/GB

For a small PokeAPI instance:
- **Development/Testing**: ~$2-5/month (minimal resources)
- **Production**: ~$10-30/month (depending on traffic and resources)

## Optional: Set Up GraphQL (Hasura)

If you want to deploy the GraphQL engine (Hasura):

1. Create a separate app for Hasura
2. Use the `hasura/graphql-engine` Docker image
3. Connect it to the same PostgreSQL database
4. Follow Hasura's Fly.io deployment guide

This is beyond the scope of this basic setup but can be added later.

## Additional Resources

- [Fly.io Documentation](https://fly.io/docs/)
- [Fly.io Postgres Guide](https://fly.io/docs/postgres/)
- [PokeAPI Documentation](https://pokeapi.co/docs/v2)
- [Django Deployment Checklist](https://docs.djangoproject.com/en/3.2/howto/deployment/checklist/)

## Security Recommendations

1. **Set a strong Django SECRET_KEY**:
   ```bash
   flyctl secrets set SECRET_KEY="your-secret-key-here" --app your-pokeapi-app-name
   ```

2. **Configure ALLOWED_HOSTS** (optional, currently set to "*"):
   ```bash
   flyctl secrets set ALLOWED_HOSTS="your-pokeapi-app-name.fly.dev" --app your-pokeapi-app-name
   ```

3. **Review security settings** in `config/docker-compose.py` for production use

4. **Enable automatic PostgreSQL backups** in Fly.io dashboard

---

Happy deploying! If you run into any issues, check the Fly.io community forum or the PokeAPI GitHub issues.
