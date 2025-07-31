# Docker Build and Deployment Guide

This repository includes automated Docker image building and versioning for the observability demo web application.

## 🚀 Features

- **Automated Docker Builds**: GitHub Actions workflow that builds and pushes images to both DockerHub and GitHub Container Registry (GHCR)
- **Smart Versioning**: Automatic version generation based on git branches, commits, and tags
- **Multi-Platform Support**: Builds for both `linux/amd64` and `linux/arm64` architectures
- **Security Scanning**: Automated vulnerability scanning with Trivy
- **Feature Branch Support**: Special versioning script for development workflows

## 📦 Container Registries

Images are automatically published to:

- **Docker Hub**: `docker.io/knappmi14/observability-demo-app/web-app`
- **GitHub Container Registry**: `ghcr.io/knappmi/observability-demo-app/web-app`

## 🏷️ Versioning Strategy

The system uses different versioning strategies based on the branch:

### Branch-Based Versioning

| Branch Type | Version Pattern | Example | Environment |
|-------------|----------------|---------|-------------|
| `main` | `1.0.0-{commit}` | `1.0.0-abc1234` | Production |
| `develop` | `1.0.0-dev-{commit}` | `1.0.0-dev-abc1234` | Development |
| `feature/*` | `1.0.0-feat-{name}-{commit}` | `1.0.0-feat-auth-abc1234` | Development |
| `release/*` | `{version}-rc-{commit}` | `2.0.0-rc-abc1234` | Staging |
| `hotfix/*` | `{version}-hotfix-{commit}` | `1.0.1-hotfix-abc1234` | Staging |
| Tags | `{tag}` | `1.0.0` | Production |

## 🛠️ Setup Instructions

### 1. Configure GitHub Secrets

Add the following secrets to your GitHub repository:

```text
DOCKERHUB_USERNAME=knappmi14
DOCKERHUB_TOKEN=your-dockerhub-access-token
```

**Note**: `GITHUB_TOKEN` is automatically provided by GitHub Actions.

### 2. Update Image Names

The workflow is already configured for your usernames:
- **DockerHub**: `knappmi14/observability-demo-app/web-app`  
- **GitHub Container Registry**: `knappmi/observability-demo-app/web-app`

### 3. DockerHub Repository Setup

1. Create a repository on DockerHub: `knappmi14/observability-demo-app`
2. Generate an access token in DockerHub settings
3. Add the token as `DOCKERHUB_TOKEN` secret in GitHub

## 🔧 Local Development

### Using Docker Compose

Build and run locally:

```bash
# Normal mode
docker-compose up web-app

# With SLO simulation enabled
docker-compose --profile testing up web-app-with-slo-sim
```

### Using Versioning Scripts

Generate version information for your current branch:

**Linux/macOS (Bash):**
```bash
# Make script executable
chmod +x scripts/generate-version.sh

# Generate version info
./scripts/generate-version.sh

# Generate with Docker tags
./scripts/generate-version.sh --show-docker-tags

# Generate for specific branch
./scripts/generate-version.sh -b feature/user-auth

# Output to file as JSON
./scripts/generate-version.sh -f json -o version.json
```

**Windows (PowerShell):**
```powershell
# Generate version info
.\scripts\generate-version.ps1

# Generate with Docker tags
.\scripts\generate-version.ps1 -ShowDockerTags

# Generate for specific branch
.\scripts\generate-version.ps1 -Branch feature/user-auth

# Output to file as JSON
.\scripts\generate-version.ps1 -Format json -OutputFile version.json
```

### Manual Docker Build

```bash
# Generate version info
source <(./scripts/generate-version.sh -f export)

# Build image
docker build \
  --build-arg VERSION=$VERSION \
  --build-arg VERSION_LABEL=$VERSION_LABEL \
  --build-arg COMMIT_SHA=$COMMIT_SHA \
  --build-arg BUILD_TIMESTAMP=$BUILD_TIMESTAMP \
  -t myregistry/observability-demo:$VERSION \
  ./web-app

# Run container
docker run -p 5000:5000 \
  -e VERSION_LABEL=$VERSION_LABEL \
  -e OTEL_SERVICE_VERSION=$VERSION \
  myregistry/observability-demo:$VERSION
```

## 🚦 GitHub Actions Workflow

The workflow triggers on:
- **Push to main/develop**: Builds and pushes production/development images
- **Pull Requests**: Builds images for testing (no push)
- **Tags**: Builds and pushes release images
- **Manual Trigger**: Via GitHub Actions UI

### Workflow Features

- ✅ Multi-platform builds (AMD64 + ARM64)
- ✅ Automatic version generation
- ✅ Security vulnerability scanning
- ✅ Build caching for faster builds
- ✅ Comprehensive build summaries
- ✅ Proper image labeling and metadata

## 🏗️ Build Arguments and Environment Variables

### Build Arguments
- `VERSION`: Semantic version
- `VERSION_LABEL`: Human-readable version label
- `COMMIT_SHA`: Git commit SHA
- `BUILD_TIMESTAMP`: Build timestamp

### Runtime Environment Variables
- `VERSION_LABEL`: Version label for the application
- `OTEL_SERVICE_VERSION`: OpenTelemetry service version
- `SIM_BAD`: Enable SLO simulation (true/false)
- `ERROR_RATE`: Error simulation rate (0.0-1.0)
- `LATENCY_SIMULATION`: Enable latency simulation
- `MAX_LATENCY`: Maximum latency in seconds
- `OUTAGE_SIMULATION`: Enable outage simulation

## 📋 Image Tags

Each build generates multiple tags:

### Production (main branch)
- `latest`
- `1.0.0-abc1234` (version-commit)
- `main-abc1234` (branch-commit)

### Development (develop branch)
- `develop`
- `1.0.0-dev-abc1234`
- `develop-latest`

### Feature Branches
- `feature-name-abc1234`
- `feature-name-latest`

### Pull Requests
- `pr-123` (PR number)

## 🔒 Security

- **Vulnerability Scanning**: All images are scanned with Trivy
- **Non-root User**: Container runs as non-root user
- **Minimal Base Image**: Uses Python slim image
- **Security Patches**: Regular base image updates

## 📊 Monitoring and Observability

The application includes built-in endpoints for monitoring:

- `/health` - Health check endpoint
- `/metrics` - Prometheus metrics
- `/version` - Version information
- `/slo-config` - SLO simulation configuration

## 🐛 Troubleshooting

### Common Issues

**Build fails with "permission denied":**
```bash
chmod +x scripts/generate-version.sh
```

**Docker push fails:**
- Check DockerHub credentials in GitHub secrets
- Verify repository exists on DockerHub
- Ensure proper repository permissions

**Version script fails:**
- Ensure you're in a git repository
- Check git configuration
- Verify script permissions

### Debug Commands

```bash
# Check git status
git status
git branch --show-current

# Test Docker build locally
docker build -t test ./web-app

# Verify image
docker run --rm test python -c "import flask; print('Flask imported successfully')"
```

## 🤝 Contributing

1. Create a feature branch: `git checkout -b feature/your-feature`
2. Make your changes
3. Test locally with Docker Compose
4. Push branch - GitHub Actions will build test images
5. Create Pull Request
6. After merge, images are automatically built and pushed

## 📚 Additional Resources

- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Multi-platform Builds](https://docs.docker.com/build/building/multi-platform/)
- [Container Security](https://docs.docker.com/engine/security/)
