from flask import Flask, request
from threading import Thread
from prometheus_client import start_http_server, Summary, Counter, Gauge, Histogram

# OpenTelemetry imports for manual instrumentation
from opentelemetry import trace, metrics
from opentelemetry.trace import Status, StatusCode
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter

# Get ENV variables for SLO simulation
import os
import random
import time

SIM_BAD = os.getenv("SIM_BAD", "false").lower() == "true"
ERROR_RATE = float(os.getenv("ERROR_RATE", "0.2"))  # Default 20% error rate when SIM_BAD is true
LATENCY_SIMULATION = os.getenv("LATENCY_SIMULATION", "false").lower() == "true"
MAX_LATENCY = float(os.getenv("MAX_LATENCY", "2.0"))  # Default 2 seconds max latency
OUTAGE_SIMULATION = os.getenv("OUTAGE_SIMULATION", "false").lower() == "true"

# Version information for canary deployments
VERSION_LABEL = os.getenv("VERSION_LABEL", "v1.0.0-unknown")
SERVICE_VERSION = os.getenv("OTEL_SERVICE_VERSION", "1.0.0")

# Initialize OpenTelemetry
tracer = trace.get_tracer(__name__)

# Basic flask app to test canary deployment
app = Flask("python-web-app")

# Define root route
@app.route("/")
def root():
    with tracer.start_as_current_span("root_endpoint") as span:
        # Add custom attributes to the span
        span.set_attribute("slo.sim_bad", SIM_BAD)
        span.set_attribute("slo.error_rate", ERROR_RATE)
        span.set_attribute("service.version", SERVICE_VERSION)
        span.set_attribute("version.label", VERSION_LABEL)
        
        # Simulate latency
        latency = simulate_latency()
        span.set_attribute("response.latency_ms", latency * 1000)
        
        # Check if service should fail
        if not health_sim():
            span.set_status(Status(StatusCode.ERROR, "Service simulation failure"))
            span.set_attribute("response.status", "error")
            return f"Service Unavailable [{VERSION_LABEL}]", 503
        
        span.set_attribute("response.status", "success")
        return f"Application is running! [{VERSION_LABEL}] (Response time: {latency:.2f}s)"

# K8s health endpoint
@app.route("/health")
def health():
    with tracer.start_as_current_span("health_check") as span:
        # Simulate health check with randomizer
        is_healthy = health_sim()
        span.set_attribute("health.status", "healthy" if is_healthy else "unhealthy")
        span.set_attribute("slo.sim_bad", SIM_BAD)
        span.set_attribute("service.version", SERVICE_VERSION)
        span.set_attribute("version.label", VERSION_LABEL)
        
        if is_healthy:
            span.set_attribute("http.status_code", 200)
            return f"OK [{VERSION_LABEL}]", 200
        else:
            span.set_status(Status(StatusCode.ERROR, "Health check failed"))
            span.set_attribute("http.status_code", 500)
            return f"ERROR [{VERSION_LABEL}]", 500

# Promtheus metrics
@app.route("/metrics")
def metrics():
    return "# HELP flask_requests_total Total number of requests\n# TYPE flask_requests_total counter\nflask_requests_total 0\n"

# Version endpoint for canary identification
@app.route("/version")
def version():
    with tracer.start_as_current_span("version_endpoint") as span:
        span.set_attribute("service.version", SERVICE_VERSION)
        span.set_attribute("version.label", VERSION_LABEL)
        
        version_info = {
            "version": SERVICE_VERSION,
            "label": VERSION_LABEL,
            "slo_config": {
                "sim_bad": SIM_BAD,
                "error_rate": ERROR_RATE,
                "latency_simulation": LATENCY_SIMULATION,
                "outage_simulation": OUTAGE_SIMULATION
            },
            "deployment_type": "canary" if "canary" in VERSION_LABEL.lower() else "stable"
        }
        return version_info

# SLO Configuration endpoint
@app.route("/slo-config")
def slo_config():
    """Returns current SLO simulation configuration"""
    config = {
        "service_info": {
            "version": SERVICE_VERSION,
            "label": VERSION_LABEL,
            "deployment_type": "canary" if "canary" in VERSION_LABEL.lower() else "stable"
        },
        "slo_simulation": {
            "sim_bad": SIM_BAD,
            "error_rate": ERROR_RATE,
            "latency_simulation": LATENCY_SIMULATION,
            "max_latency": MAX_LATENCY,
            "outage_simulation": OUTAGE_SIMULATION
        },
        "description": {
            "sim_bad": "Master switch for all bad SLO simulations",
            "error_rate": "Probability of returning errors (0.0-1.0)",
            "latency_simulation": "Enable artificial latency delays",
            "max_latency": "Maximum latency in seconds",
            "outage_simulation": "Enable complete service outages (5% chance)"
        }
    }
    return config

# Users endpoint to return test data
@app.route("/users")
def users():
    with tracer.start_as_current_span("users_endpoint") as span:
        # Simulate latency
        latency = simulate_latency()
        span.set_attribute("response.latency_ms", latency * 1000)
        span.set_attribute("slo.sim_bad", SIM_BAD)
        span.set_attribute("service.version", SERVICE_VERSION)
        span.set_attribute("version.label", VERSION_LABEL)
        
        # Check health before processing
        if not health_sim():
            span.set_status(Status(StatusCode.ERROR, "Service simulation failure"))
            span.set_attribute("response.status", "error")
            return f"Service Unavailable [{VERSION_LABEL}]", 503
        
        users_data = {"users": [
            {"id": 1, "name": "John Doe", "email": "john@example.com"},
            {"id": 2, "name": "Jane Smith", "email": "jane@example.com"},
            {"id": 3, "name": "Bob Johnson", "email": "bob@example.com"}
        ], "response_time": f"{latency:.2f}s"}
        
        span.set_attribute("response.status", "success")
        span.set_attribute("users.count", len(users_data["users"]))
        return users_data


# SLO Simulation Functions
def simulate_latency():
    """Simulate network latency issues"""
    with tracer.start_as_current_span("simulate_latency") as span:
        if LATENCY_SIMULATION and SIM_BAD:
            latency = random.uniform(0.1, MAX_LATENCY)
            span.set_attribute("latency.simulated", True)
            span.set_attribute("latency.duration_seconds", latency)
            time.sleep(latency)
            return latency
        span.set_attribute("latency.simulated", False)
        return 0

def simulate_error_rate():
    """Simulate error rate based on ERROR_RATE environment variable"""
    with tracer.start_as_current_span("simulate_error_rate") as span:
        if SIM_BAD:
            should_error = random.random() < ERROR_RATE
            span.set_attribute("error.simulation_enabled", True)
            span.set_attribute("error.should_fail", should_error)
            span.set_attribute("error.configured_rate", ERROR_RATE)
            return should_error
        span.set_attribute("error.simulation_enabled", False)
        return False

def simulate_outage():
    """Simulate complete service outage"""
    with tracer.start_as_current_span("simulate_outage") as span:
        if OUTAGE_SIMULATION and SIM_BAD:
            # 5% chance of complete outage when outage simulation is enabled
            should_outage = random.random() < 0.05
            span.set_attribute("outage.simulation_enabled", True)
            span.set_attribute("outage.should_fail", should_outage)
            return should_outage
        span.set_attribute("outage.simulation_enabled", False)
        return False

def health_sim():
    """
    Comprehensive health simulation that checks for:
    - Complete outages
    - Error rate simulation
    - Returns False if any failure condition is met
    """
    with tracer.start_as_current_span("health_simulation") as span:
        span.set_attribute("slo.sim_bad", SIM_BAD)
        
        # Check for complete outage first
        if simulate_outage():
            span.set_attribute("failure.type", "outage")
            return False
        
        # Check for error rate simulation
        if simulate_error_rate():
            span.set_attribute("failure.type", "error_rate")
            return False
        
        span.set_attribute("failure.type", "none")
        return True

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000, debug=False)