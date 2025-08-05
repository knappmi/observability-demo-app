# Observability Demo Application

A lightweight Flask web application designed for testing observability telemetry, monitoring, and failure scenarios. This application provides comprehensive instrumentation with OpenTelemetry, Prometheus metrics, and configurable SLO simulation capabilities.

## Features

- **OpenTelemetry Integration**: Full distributed tracing with manual instrumentation
- **Prometheus Metrics**: Built-in metrics endpoint for monitoring
- **SLO Simulation**: Configurable error rates, latency, and outage scenarios
- **Health Monitoring**: Kubernetes-ready health and readiness endpoints
- **Version Tracking**: Comprehensive version and deployment information
- **Docker Support**: Multi-platform container builds with automated CI/CD
- **Canary Deployment Ready**: Version labeling for deployment strategies

## Quick Start

### Local Development

#### Prerequisites
- Python 3.11 or higher
- Docker (optional)
- Git

#### Running Locally

1. Clone the repository:
   ```bash
   git clone https://github.com/knappmi/observability-demo-app.git
   cd observability-demo-app
   ```

2. Install dependencies:
   ```bash
   cd web-app
   pip install -r requirements.txt
   ```

3. Run the application:
   ```bash
   python main.py
   ```

The application will be available at `http://localhost:5000`

#### Using Docker

1. Build and run with Docker Compose:
   ```bash
   docker-compose up web-app
   ```

2. Or build manually:
   ```bash
   docker build -t observability-demo ./web-app
   docker run -p 5000:5000 observability-demo
   ```

## API Endpoints

### Core Endpoints

- `GET /` - Root endpoint returning application status
- `GET /health` - Health check endpoint for Kubernetes probes
- `GET /version` - Version and deployment information
- `GET /users` - Sample data endpoint with user information
- `GET /metrics` - Prometheus metrics endpoint
- `GET /slo-config` - SLO simulation configuration

### Health Check Response
```json
{
  "status": "OK",
  "version": "v1.0.0-main-abc1234"
}
```

### Version Information Response
```json
{
  "version": "1.0.0",
  "label": "v1.0.0-main-abc1234",
  "slo_config": {
    "sim_bad": false,
    "error_rate": 0.2,
    "latency_simulation": false,
    "outage_simulation": false
  },
  "deployment_type": "stable"
}
```

## Configuration

### Environment Variables

#### Application Settings
- `VERSION_LABEL` - Human-readable version label (default: "v1.0.0-unknown")
- `OTEL_SERVICE_VERSION` - OpenTelemetry service version (default: "1.0.0")

#### SLO Simulation
- `SIM_BAD` - Master switch for SLO simulations (default: "false")
- `ERROR_RATE` - Probability of returning errors 0.0-1.0 (default: "0.2")
- `LATENCY_SIMULATION` - Enable artificial latency (default: "false")
- `MAX_LATENCY` - Maximum latency in seconds (default: "2.0")
- `OUTAGE_SIMULATION` - Enable complete service outages (default: "false")

### Example Configuration

#### Normal Operation
```bash
export VERSION_LABEL="v1.0.0-production"
export SIM_BAD=false
python main.py
```

#### Testing with SLO Simulation
```bash
export VERSION_LABEL="v1.0.0-test"
export SIM_BAD=true
export ERROR_RATE=0.3
export LATENCY_SIMULATION=true
export MAX_LATENCY=2.0
export OUTAGE_SIMULATION=true
python main.py
```

## Docker Deployment

### Pre-built Images

Images are automatically built and published to:
- **Docker Hub**: `knappmi14/observability-demo-app/web-app`
- **GitHub Container Registry**: `ghcr.io/knappmi/observability-demo-app/web-app`

### Available Tags

- `latest` - Latest stable release from main branch
- `develop` - Latest development build
- `v1.0.0` - Specific version releases
- `main-abc1234` - Commit-specific builds

### Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: observability-demo
spec:
  replicas: 3
  selector:
    matchLabels:
      app: observability-demo
  template:
    metadata:
      labels:
        app: observability-demo
    spec:
      containers:
      - name: web-app
        image: knappmi14/observability-demo-app/web-app:latest
        ports:
        - containerPort: 5000
        env:
        - name: VERSION_LABEL
          value: "v1.0.0-k8s"
        - name: SIM_BAD
          value: "false"
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

## Observability Integration

### OpenTelemetry

The application provides comprehensive OpenTelemetry instrumentation:

- **Traces**: All endpoints automatically create spans with custom attributes
- **Attributes**: Service version, SLO configuration, response metrics
- **Error Tracking**: Failed requests generate error spans with status codes

### Prometheus Metrics

Basic Prometheus metrics are available at `/metrics`:
- Request counters
- Response time histograms
- Error rate tracking

### Custom Attributes

Each trace includes:
- `service.version` - Application version
- `version.label` - Deployment label
- `slo.sim_bad` - SLO simulation status
- `response.latency_ms` - Response latency
- `response.status` - Success/error status

## Testing and Validation

### Automated Testing

The repository includes scripts for testing:

```bash
# Generate version information
./scripts/generate-version.sh

# Test Docker build locally
./scripts/test-docker-build.sh
```

### SLO Simulation Testing

Test different failure scenarios:

```bash
# Test with 30% error rate
curl -H "SIM_BAD: true" -H "ERROR_RATE: 0.3" http://localhost:5000/

# Test with latency simulation
curl -H "LATENCY_SIMULATION: true" http://localhost:5000/
```

## CI/CD Pipeline

### Automated Builds

GitHub Actions automatically:
- Builds multi-platform Docker images (AMD64/ARM64)
- Runs security scans with Trivy
- Pushes to DockerHub and GitHub Container Registry
- Generates version tags based on git branches

### Versioning Strategy

- **main branch**: Production releases (`1.0.0-abc1234`)
- **develop branch**: Development builds (`1.0.0-dev-abc1234`)
- **feature branches**: Feature builds (`1.0.0-feat-name-abc1234`)
- **git tags**: Release versions (`v1.0.0`)

## Bad Configuration Tags 🚨

This project supports special "bad configuration" tags that automatically build Docker images with pre-configured problematic SLO settings. These are perfect for testing observability tools, alerting systems, and training scenarios.

### Quick Usage

Create and push tags with special suffixes to get pre-configured problematic images:

```bash
# Bad configuration (30% error rate, latency issues)
git tag v1.0.0-bad
git push origin v1.0.0-bad

# Chaos configuration (50% error rate, extreme latency)  
git tag v1.0.0-chaos
git push origin v1.0.0-chaos

# Normal configuration (good SLO settings)
git tag v1.0.0
git push origin v1.0.0
```

### Available Images

After the GitHub Actions build completes, images are published to:

- **DockerHub**: `knappmi14/observability-demo-app:TAG`
- **GHCR**: `ghcr.io/knappmi/observability-demo-app:TAG`

#### Configuration Presets

| Tag Pattern | Error Rate | Latency Sim | Outage Sim | Max Latency | Use Case |
|-------------|------------|-------------|------------|-------------|----------|
| `v*` (normal) | 10% | ❌ | ❌ | 1.0s | Production-like |
| `v*-bad` | 30% | ✅ | ✅ | 3.0s | Testing alerts |
| `v*-chaos` | 50% | ✅ | ✅ | 5.0s | Extreme testing |

### Example Usage

```bash
# Test different configurations side by side
docker run -p 5000:5000 knappmi14/observability-demo-app:latest     # Good
docker run -p 5001:5000 knappmi14/observability-demo-app:bad        # Bad
docker run -p 5002:5000 knappmi14/observability-demo-app:chaos      # Chaos

# Verify configurations
curl http://localhost:5000/slo-config  # Normal config
curl http://localhost:5001/slo-config  # Bad config  
curl http://localhost:5002/slo-config  # Chaos config
```

### Helper Scripts

Use the provided scripts to create tags easily:

**PowerShell (Windows):**
```powershell
.\scripts\create-bad-tag.ps1 -Version 1.0.0 -ConfigType bad
.\scripts\create-bad-tag.ps1 -Version 1.0.0 -ConfigType chaos
```

**Bash (Linux/Mac):**
```bash
./scripts/create-bad-tag.sh 1.0.0 bad
./scripts/create-bad-tag.sh 1.0.0 chaos
```

📖 **Full Documentation**: [docs/BAD_CONFIG_TAGS.md](docs/BAD_CONFIG_TAGS.md)

## Development

### Project Structure

```
observability-demo-app/
├── web-app/
│   ├── main.py              # Main Flask application
│   ├── requirements.txt     # Python dependencies
│   └── Dockerfile          # Container build definition
├── scripts/
│   ├── generate-version.sh  # Version generation script
│   └── test-docker-build.sh # Local testing script
├── .github/workflows/       # CI/CD pipeline definitions
└── docker-compose.yml      # Local development setup
```

### Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes and test locally
4. Commit your changes: `git commit -am 'Add new feature'`
5. Push to the branch: `git push origin feature/your-feature`
6. Create a Pull Request

## Use Cases

This application is designed for:

- **Observability Testing**: Validate monitoring and alerting systems
- **Load Testing**: Generate realistic failure patterns for testing
- **Training**: Demonstrate observability best practices
- **Canary Deployments**: Test deployment strategies with version tracking
- **SLO Validation**: Verify service level objective monitoring
- **Chaos Engineering**: Simulate controlled failure scenarios

## Security

- Containers run as non-root user
- Automated vulnerability scanning
- Minimal base image (Python slim)
- No sensitive data exposure
- Health check endpoints for monitoring

## License

This project is licensed under the MIT License. See the LICENSE file for details.

## Support

For issues, questions, or contributions:
- Create an issue in the GitHub repository
- Review existing documentation in the `/docs` directory
- Check the CI/CD pipeline status in GitHub Actions
