# Use Python 3.11 slim image as base
FROM python:3.11-slim

# Build arguments for version information and SLO configuration
ARG VERSION="1.0.0-local"
ARG VERSION_LABEL="v1.0.0-local-dev"
ARG COMMIT_SHA="unknown"
ARG BUILD_TIMESTAMP="unknown"
ARG SIM_BAD="false"
ARG ERROR_RATE="0.1"
ARG LATENCY_SIMULATION="false"
ARG OUTAGE_SIMULATION="false"
ARG MAX_LATENCY="1.0"

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY main.py .

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser
RUN chown -R appuser:appuser /app
USER appuser

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Set default environment variables
ENV PYTHONUNBUFFERED=1
ENV FLASK_APP=main.py

# Set version and build information
ENV OTEL_SERVICE_VERSION=${VERSION}
ENV VERSION_LABEL=${VERSION_LABEL}
ENV BUILD_COMMIT_SHA=${COMMIT_SHA}
ENV BUILD_TIMESTAMP=${BUILD_TIMESTAMP}

# Set SLO configuration from build arguments
ENV SIM_BAD=${SIM_BAD}
ENV ERROR_RATE=${ERROR_RATE}
ENV LATENCY_SIMULATION=${LATENCY_SIMULATION}
ENV OUTAGE_SIMULATION=${OUTAGE_SIMULATION}
ENV MAX_LATENCY=${MAX_LATENCY}

# Add labels for better container identification
LABEL org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${COMMIT_SHA}" \
      org.opencontainers.image.created="${BUILD_TIMESTAMP}" \
      app.slo.sim_bad="${SIM_BAD}" \
      app.slo.error_rate="${ERROR_RATE}" \
      app.slo.latency_simulation="${LATENCY_SIMULATION}" \
      app.slo.outage_simulation="${OUTAGE_SIMULATION}" \
      app.slo.max_latency="${MAX_LATENCY}"

# Run the application
CMD ["python", "main.py"]
