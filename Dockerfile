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
