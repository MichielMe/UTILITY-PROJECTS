@echo off
setlocal enabledelayedexpansion

echo Creating new FastAPI project...

:: Create a new FastAPI project using uv
uv init .

:: Remove Python files in root
del *.py

:: Add dependencies
uv add fastapi --extra standard
uv add loguru pydantic-settings

echo Project created successfully!

echo Creating Dockerfile...

:: Create Dockerfile
(
echo # An example using multi-stage image builds to create a final image without uv.
echo.
echo # First, build the application in the `/app` directory.
echo # See `Dockerfile` for details.
echo FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim AS builder
echo ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy
echo.
echo # Disable Python downloads, because we want to use the system interpreter
echo # across both images. If using a managed Python version, it needs to be
echo # copied from the build image into the final image; see `standalone.Dockerfile`
echo # for an example.
echo ENV UV_PYTHON_DOWNLOADS=0
echo.
echo WORKDIR /app
echo RUN --mount=type=cache,target=/root/.cache/uv \
echo     --mount=type=bind,source=uv.lock,target=uv.lock \
echo     --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
echo     uv sync --frozen --no-install-project --no-dev
echo ADD . /app
echo RUN --mount=type=cache,target=/root/.cache/uv \
echo     uv sync --frozen --no-dev
echo.
echo.
echo # Then, use a final image without uv
echo FROM python:3.13-slim-bookworm
echo # It is important to use the image that matches the builder, as the path to the
echo # Python executable must be the same, e.g., using `python:3.11-slim-bookworm`
echo # will fail.
echo.
echo # Copy the application from the builder
echo COPY --from=builder --chown=app:app /app /app
echo.
echo # Place executables in the environment at the front of the path
echo ENV PATH="/app/.venv/bin:$PATH"
echo.
echo # Run the FastAPI application by default
echo CMD ["fastapi", "dev", "--host", "0.0.0.0", "/app/app/main.py"]
) > Dockerfile

echo Dockerfile created successfully!
echo Creating Docker compose file...

:: Create docker-compose.yml
(
echo services:
echo   app:
echo     build:
echo       context: .
echo       dockerfile: Dockerfile
echo     ports:
echo       - "8000:8000"
) > docker-compose.yml

echo Docker compose file created successfully!

echo Creating project structure...

echo Create .env file
type nul > .env

:: Create main app directory
mkdir app
cd app

:: Create root level files
type nul > __init__.py
type nul > main.py

:: Create API directory and files
mkdir api
type nul > api\__init__.py

:: Create core directory and files
mkdir core
type nul > core\__init__.py
type nul > core\config.py
type nul > core\middleware.py

:: Create core/config.py content
(
echo from pydantic_settings import BaseSettings
echo.
echo class Settings^(BaseSettings^):
echo     PROJECT_NAME: str = "FastAPI Project"
echo     LOG_LEVEL: str = "INFO"
echo     BACKEND_CORS_ORIGINS: list[str] = []
echo.
echo settings = Settings^(^)
) > core\config.py

:: Create core/__init__.py content
(
echo from .config import settings
echo.
echo __all__ = ["settings"]
) > core\__init__.py

:: Create services directory and files
mkdir services
type nul > services\__init__.py

:: Create models directory and files
mkdir models
type nul > models\__init__.py

:: Create schemas directory and files
mkdir schemas
type nul > schemas\__init__.py

echo Project structure created successfully!

:: Add boilerplate code
echo Adding boilerplate code...

:: Create main.py content
(
echo from fastapi import FastAPI
echo from contextlib import asynccontextmanager
echo from loguru import logger
echo from app.core import settings
echo.
echo @asynccontextmanager
echo async def lifespan^(app: FastAPI^):
echo     """
echo     Lifespan context manager for the FastAPI app.
echo     """
echo     logger.info^(f"App started. {settings.PROJECT_NAME}"^)
echo     yield
echo     logger.info^(f"App shutting down. {settings.PROJECT_NAME}"^)
echo.
echo app = FastAPI^(title=settings.PROJECT_NAME, lifespan=lifespan^)
echo.
echo if settings.BACKEND_CORS_ORIGINS:
echo     app.add_middleware^(
echo         CORSMiddleware,
echo         allow_origins=settings.BACKEND_CORS_ORIGINS,
echo         allow_credentials=True,
echo         allow_methods=["*"],
echo         allow_headers=["*"],
echo     ^)
echo.
echo.
echo @app.get^("/"^)
echo def read_root^(^):
echo     return {"message": f"Welcome to {settings.PROJECT_NAME}"}
) > main.py

echo Boilerplate code added successfully!
cd ..

echo Project setup complete!
echo Creating Makefile...

:: Create Makefile
(
echo make run-uv:
echo 	uv run fastapi dev --host 0.0.0.0 --port 8000
echo.
echo make run-docker:
echo 	docker compose up --build
echo.
echo make down-docker:
echo 	docker compose down
echo.
echo make clean:
echo 	rm -rf .venv
echo 	rm -rf .pytest_cache
echo 	rm -rf .mypy_cache
echo 	rm -rf .ruff_cache
echo 	rm -rf .cache
) > Makefile

:: Create Windows run scripts
(
echo @echo off
echo uv run fastapi dev --host 0.0.0.0 --port 8000
) > run-uv.bat

(
echo @echo off
echo docker compose up --build
) > run-docker.bat

(
echo @echo off
echo docker compose down
) > stop-docker.bat

(
echo @echo off
echo if exist .venv rd /s /q .venv
echo if exist .pytest_cache rd /s /q .pytest_cache
echo if exist .mypy_cache rd /s /q .mypy_cache
echo if exist .ruff_cache rd /s /q .ruff_cache
echo if exist .cache rd /s /q .cache
) > clean.bat

echo Batch files created successfully!
echo Run the project with 'run-uv.bat' or 'run-docker.bat' 