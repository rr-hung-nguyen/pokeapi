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
