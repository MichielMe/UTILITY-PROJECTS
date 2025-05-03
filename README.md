# UTILITY-PROJECTS

A collection of development utilities, boilerplates, and project templates to jumpstart various types of applications.

## Overview

This repository contains various development utilities and project templates designed to simplify the project initialization process. It includes:

- **Boilerplate Templates**: Pre-configured project setups for different frameworks and technologies
- **Test Projects**: Example implementations using the boilerplates
- **Monitoring Tools**: Utilities for application monitoring (in development)

## Boilerplates

### uv-FastAPI

A modern Python FastAPI project template configured with uv package manager, Docker support, and a well-structured project layout.

**Features:**

- FastAPI framework with standardized project structure
- UV package manager integration for faster dependency management
- Docker and Docker Compose configuration
- Logging with Loguru
- Environment configuration with Pydantic Settings
- Cross-platform support (Linux/macOS via sh script, Windows via bat script)

**Usage:**

```bash
# On Linux/macOS
./boilerplates/uv-fastapi/create-uv-fastapi-project.sh

# On Windows
boilerplates\uv-fastapi\create-uv-fastapi-project.bat
```

The script will create a new FastAPI project with the following structure:

```
├── app/
│   ├── __init__.py
│   ├── main.py
│   ├── api/
│   │   └── __init__.py
│   ├── core/
│   │   ├── __init__.py
│   │   ├── config.py
│   │   └── middleware.py
│   ├── models/
│   │   └── __init__.py
│   ├── schemas/
│   │   └── __init__.py
│   └── services/
│       └── __init__.py
├── Dockerfile
├── docker-compose.yml
├── Makefile
├── .env
└── pyproject.toml
```

**Running the project:**

```bash
# Using uv
make run-uv
# or on Windows
run-uv.bat

# Using Docker
make run-docker
# or on Windows
run-docker.bat
```

### expo-react-native

Template for React Native projects using Expo (under development).

### react-tailwind-daisyui

Template for React projects with Tailwind CSS and DaisyUI (under development).

## Test Projects

Example implementations using the boilerplates can be found in the `test-projects` directory:

- `uv-fastapi-test-projects`: Examples using the uv-FastAPI boilerplate

## Monitoring

Utilities for application monitoring (under development).

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is open source and available under the [MIT License](LICENSE).
