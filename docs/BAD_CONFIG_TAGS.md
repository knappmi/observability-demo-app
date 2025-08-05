# Bad Configuration Tags 🚨

This document explains how to create Docker images with pre-configured "bad" SLO settings for testing and demonstration purposes.

## Overview

The GitHub Actions workflow automatically detects special tag patterns and builds Docker images with different SLO configurations baked in. This allows you to quickly deploy problematic services for testing observability tools, alerting systems, and SLO monitoring.

## Tag Patterns

### Normal Tags
- `v1.0.0` - Production-ready configuration with good SLO settings
- `v2.1.3` - Any semantic version tag builds with default (good) settings

### Bad Configuration Tags
- `v1.0.0-bad` - Pre-configured with moderate bad SLO settings
- `v2.1.0-bad` - Any version with `-bad` suffix

**Bad Configuration:**
```env
SIM_BAD=true
ERROR_RATE=0.3          # 30% error rate
LATENCY_SIMULATION=true
OUTAGE_SIMULATION=true
MAX_LATENCY=3.0         # 3 second max latency
```

### Chaos Configuration Tags
- `v1.0.0-chaos` - Pre-configured with extreme bad SLO settings
- `v2.1.0-chaos` - Any version with `-chaos` suffix

**Chaos Configuration:**
```env
SIM_BAD=true
ERROR_RATE=0.5          # 50% error rate
LATENCY_SIMULATION=true
OUTAGE_SIMULATION=true
MAX_LATENCY=5.0         # 5 second max latency
```

## How to Create and Push Tags

### Creating a Bad Configuration Release

```bash
# Create and push a bad configuration tag
git tag v1.0.0-bad
git push origin v1.0.0-bad
```

### Creating a Chaos Configuration Release

```bash
# Create and push a chaos configuration tag
git tag v1.0.0-chaos
git push origin v1.0.0-chaos
```

### Creating a Normal Release

```bash
# Create and push a normal tag (good configuration)
git tag v1.0.0
git push origin v1.0.0
```

## Automatic Builds

When you push any tag, GitHub Actions will:

1. **Detect the tag pattern** and configure SLO settings accordingly
2. **Build multi-platform Docker images** (linux/amd64, linux/arm64)
3. **Push to both registries:**
   - **Docker Hub**: `knappmi14/observability-demo-app:TAG`
   - **GitHub Container Registry**: `ghcr.io/knappmi/observability-demo-app:TAG`
4. **Create special tags:**
   - Normal tags: `latest`, `TAG`
   - Bad tags: `bad`, `TAG`
   - Chaos tags: `chaos`, `TAG`

## Published Image Examples

### Normal Configuration
```bash
# Pull normal image
docker pull knappmi14/observability-demo-app:v1.0.0
docker pull ghcr.io/knappmi/observability-demo-app:latest

# Run with good SLO settings
docker run -p 5000:5000 knappmi14/observability-demo-app:v1.0.0
```

### Bad Configuration
```bash
# Pull bad configuration image
docker pull knappmi14/observability-demo-app:v1.0.0-bad
docker pull ghcr.io/knappmi/observability-demo-app:bad

# Run with 30% error rate and latency issues
docker run -p 5000:5000 knappmi14/observability-demo-app:v1.0.0-bad
```

### Chaos Configuration
```bash
# Pull chaos configuration image
docker pull knappmi14/observability-demo-app:v1.0.0-chaos
docker pull ghcr.io/knappmi/observability-demo-app:chaos

# Run with 50% error rate and extreme latency
docker run -p 5000:5000 knappmi14/observability-demo-app:v1.0.0-chaos
```

## Deployment Examples

### Kubernetes Deployment with Bad Configuration

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app-bad
spec:
  replicas: 2
  selector:
    matchLabels:
      app: demo-app-bad
  template:
    metadata:
      labels:
        app: demo-app-bad
        config: bad
    spec:
      containers:
      - name: web-app
        image: knappmi14/observability-demo-app:v1.0.0-bad
        ports:
        - containerPort: 5000
        livenessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 5
          periodSeconds: 5
```

### Docker Compose with Multiple Configurations

```yaml
version: '3.8'
services:
  good-app:
    image: knappmi14/observability-demo-app:latest
    ports:
      - "5000:5000"
    labels:
      - "traefik.http.routers.good.rule=Host(`good.localhost`)"
  
  bad-app:
    image: knappmi14/observability-demo-app:bad
    ports:
      - "5001:5000"
    labels:
      - "traefik.http.routers.bad.rule=Host(`bad.localhost`)"
  
  chaos-app:
    image: knappmi14/observability-demo-app:chaos
    ports:
      - "5002:5000"
    labels:
      - "traefik.http.routers.chaos.rule=Host(`chaos.localhost`)"
```

## Use Cases

### 1. Testing Alerting Systems
Deploy bad configuration images to test if your monitoring alerts trigger correctly:

```bash
# Deploy bad service and verify alerts fire
kubectl apply -f deployment-bad.yaml
# Wait for alerts to trigger
# Verify alert notifications
```

### 2. SLO Monitoring Validation
Use different configurations to validate SLO monitoring:

- **Good**: Should meet all SLOs
- **Bad**: Should violate latency and error rate SLOs
- **Chaos**: Should violate all SLOs dramatically

### 3. Load Testing with Real Problems
Combine with load testing tools to simulate realistic failure scenarios:

```bash
# Run chaos configuration
docker run -d -p 5000:5000 knappmi14/observability-demo-app:chaos

# Load test against problematic service
hey -n 1000 -c 10 http://localhost:5000/
```

### 4. Training and Demos
Perfect for training scenarios where you need predictable bad behavior:

- **Training**: "Here's how the service behaves when things go wrong"
- **Demos**: Show observability tools detecting real problems
- **Workshops**: Let participants troubleshoot actual issues

## Monitoring the Configurations

All images include built-in metrics and structured logging that show:

- **Current SLO configuration** in logs and `/slo-config` endpoint
- **Real-time error rates** in Prometheus metrics
- **Latency distributions** with categorization
- **SLO violation events** in structured logs

### Check Current Configuration

```bash
# Get SLO configuration
curl http://localhost:5000/slo-config

# Get Prometheus metrics
curl http://localhost:5000/metrics
```

## Security Note

⚠️ **WARNING**: Bad and chaos configuration images are intended for testing and demonstration purposes only. **Never deploy these in production environments** as they will cause service degradation and failures.

The images are clearly labeled with their configuration in:
- Container labels
- Environment variables  
- Application logs
- Metrics endpoints

## Troubleshooting

### Image Not Building
1. Check tag format matches expected patterns
2. Verify GitHub Actions workflow is enabled
3. Check repository secrets are configured (DOCKERHUB_TOKEN, GHCR_TOKEN)

### Wrong Configuration Applied
1. Verify tag name matches pattern exactly (`-bad` or `-chaos` suffix)
2. Check GitHub Actions workflow logs for configuration detection
3. Inspect container labels: `docker inspect image:tag`

### Missing Images
1. Check both DockerHub and GHCR for the image
2. Verify build completed successfully in GitHub Actions
3. Check if tag was pushed correctly: `git tag -l`
