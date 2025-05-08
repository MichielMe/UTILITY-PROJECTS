#!/bin/bash

echo "Creating new FastAPI project..."

# Create a new FastAPI project using uv
uv init .

rm *.py

uv add fastapi --extra standard
uv add loguru pydantic-settings

echo "Project created successfully!"

echo "Creating Dockerfile..."

touch Dockerfile

cat > Dockerfile << 'EOF'
# An example using multi-stage image builds to create a final image without uv.

# First, build the application in the `/app` directory.
# See `Dockerfile` for details.
FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim AS builder
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy

# Disable Python downloads, because we want to use the system interpreter
# across both images. If using a managed Python version, it needs to be
# copied from the build image into the final image; see `standalone.Dockerfile`
# for an example.
ENV UV_PYTHON_DOWNLOADS=0

WORKDIR /app
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --frozen --no-install-project --no-dev
ADD . /app
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev


# Then, use a final image without uv
FROM python:3.13-slim-bookworm
# It is important to use the image that matches the builder, as the path to the
# Python executable must be the same, e.g., using `python:3.11-slim-bookworm`
# will fail.

# Copy the application from the builder
COPY --from=builder --chown=app:app /app /app

# Place executables in the environment at the front of the path
ENV PATH="/app/.venv/bin:$PATH"

# Run the FastAPI application by default
CMD ["fastapi", "dev", "--host", "0.0.0.0", "/app/app/main.py"]
EOF

echo "Dockerfile created successfully!"
echo "Creating Docker compose file..."

touch docker-compose.yml

cat > docker-compose.yml << 'EOF'
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "8000:8000"
EOF

echo "Docker compose file created successfully!"

echo "Creating project structure..."

echo "Create .env file"
touch .env

# Create main app directory
mkdir -p app
cd app

# Create root level files
touch __init__.py
touch main.py

# Create API directory and files
mkdir -p api
touch api/__init__.py

# Create core directory and files
mkdir -p core
touch core/__init__.py
touch core/config.py
touch core/middleware.py

cat > core/config.py << 'EOF'
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    PROJECT_NAME: str = "FastAPI Project"
    LOG_LEVEL: str = "INFO"
    BACKEND_CORS_ORIGINS: list[str] = []

settings = Settings()
EOF

cat > core/__init__.py << 'EOF'
from .config import settings

__all__ = ["settings"]
EOF

# Create services directory and files
mkdir -p services
touch services/__init__.py

# Create models directory and files
mkdir -p models
touch models/__init__.py

# Create schemas directory and files
mkdir -p schemas
touch schemas/__init__.py

echo "Project structure created successfully!"

# Boilerplate code for the project
echo "Adding boilerplate code..."

# Create main.py
cat > main.py << 'EOF'

from fastapi import FastAPI
from contextlib import asynccontextmanager
from fastapi.middleware.cors import CORSMiddleware
from loguru import logger
from app.core import settings

@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Lifespan context manager for the FastAPI app.
    """
    logger.info(f"App started. {settings.PROJECT_NAME}")
    yield
    logger.info(f"App shutting down. {settings.PROJECT_NAME}")

app = FastAPI(title=settings.PROJECT_NAME, lifespan=lifespan)

if settings.BACKEND_CORS_ORIGINS:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.BACKEND_CORS_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )


@app.get("/")
def read_root():
    return {"message": f"Welcome to {settings.PROJECT_NAME}"}
EOF

echo "Boilerplate code added successfully!"

echo "Project setup complete!"

echo "Makefile"
touch Makefile

cat > Makefile << 'EOF'
make run-uv:
	uv run fastapi dev --host 0.0.0.0 --port 8000

make run-docker:
	docker compose up --build

make down-docker:
	docker compose down

make clean:
	rm -rf .venv
	rm -rf .pytest_cache
	rm -rf .mypy_cache
	rm -rf .ruff_cache
	rm -rf .cache
EOF

echo "Makefile created successfully!"

echo "Run the project with 'make run-uv' or 'make run-docker'"