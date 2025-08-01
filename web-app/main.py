from flask import Flask, request, g
from threading import Thread
from prometheus_client import start_http_server, Summary, Counter, Gauge, Histogram

# OpenTelemetry imports for manual instrumentation
from opentelemetry import trace, metrics
from opentelemetry.trace import Status, StatusCode
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor, ConsoleSpanExporter
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource

# Get ENV variables for SLO simulation
import os
import random
import time
import json
import logging
import uuid
from datetime import datetime, timezone

# Configure structured logging for AI training
logging.basicConfig(
    level=logging.INFO,
    format='%(message)s',  # JSON format only
    handlers=[logging.StreamHandler()]
)
logger = logging.getLogger(__name__)

SIM_BAD = os.getenv("SIM_BAD", "false").lower() == "true"
ERROR_RATE = float(os.getenv("ERROR_RATE", "0.2"))  # Default 20% error rate when SIM_BAD is true
LATENCY_SIMULATION = os.getenv("LATENCY_SIMULATION", "false").lower() == "true"
MAX_LATENCY = float(os.getenv("MAX_LATENCY", "2.0"))  # Default 2 seconds max latency
OUTAGE_SIMULATION = os.getenv("OUTAGE_SIMULATION", "false").lower() == "true"

# Version information for canary deployments
VERSION_LABEL = os.getenv("VERSION_LABEL", "v1.0.0-unknown")
SERVICE_VERSION = os.getenv("OTEL_SERVICE_VERSION", "1.0.0")
SERVICE_NAME = os.getenv("OTEL_SERVICE_NAME", "observability-demo-app")
ENVIRONMENT = os.getenv("ENVIRONMENT", "production")

# Properly initialize OpenTelemetry
def setup_opentelemetry():
    """Configure OpenTelemetry with proper trace and span ID generation"""
    # Create resource with service information
    resource = Resource.create({
        "service.name": SERVICE_NAME,
        "service.version": SERVICE_VERSION,
        "service.instance.id": str(uuid.uuid4()),
        "deployment.environment": ENVIRONMENT,
        "version.label": VERSION_LABEL
    })
    
    # Create and configure tracer provider
    tracer_provider = TracerProvider(resource=resource)
    
    # Add console exporter for local development (you can see traces in logs)
    console_exporter = ConsoleSpanExporter()
    console_processor = BatchSpanProcessor(console_exporter)
    tracer_provider.add_span_processor(console_processor)
    
    # Optionally add OTLP exporter if OTEL_EXPORTER_OTLP_ENDPOINT is set
    otlp_endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT")
    if otlp_endpoint:
        otlp_exporter = OTLPSpanExporter(endpoint=otlp_endpoint)
        otlp_processor = BatchSpanProcessor(otlp_exporter)
        tracer_provider.add_span_processor(otlp_processor)
    
    # Set the global tracer provider
    trace.set_tracer_provider(tracer_provider)
    
    return trace.get_tracer(__name__)

# Initialize OpenTelemetry and get tracer
tracer = setup_opentelemetry()

class StructuredLogger:
    """Structured logging for AI training data"""
    
    @staticmethod
    def get_correlation_id():
        """Get or create correlation ID for request tracking"""
        if not hasattr(g, 'correlation_id'):
            g.correlation_id = str(uuid.uuid4())
        return g.correlation_id
    
    @staticmethod
    def log_event(event_type, **kwargs):
        """Log structured events optimized for AI training"""
        correlation_id = StructuredLogger.get_correlation_id()
        
        # Get current span context for trace correlation
        current_span = trace.get_current_span()
        span_context = current_span.get_span_context() if current_span else None
        
        event = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "event_type": event_type,
            "correlation_id": correlation_id,
            "trace_id": hex(span_context.trace_id) if span_context else None,
            "span_id": hex(span_context.span_id) if span_context else None,
            "service": {
                "name": SERVICE_NAME,
                "version": SERVICE_VERSION,
                "environment": ENVIRONMENT,
                "version_label": VERSION_LABEL
            },
            "slo_config": {
                "sim_bad": SIM_BAD,
                "error_rate": ERROR_RATE,
                "latency_simulation": LATENCY_SIMULATION,
                "outage_simulation": OUTAGE_SIMULATION
            }
        }
        
        # Add custom event data
        event.update(kwargs)
        
        # Log as JSON for AI processing
        logger.info(json.dumps(event))
        
        return correlation_id

# Basic flask app to test canary deployment
app = Flask("python-web-app")

@app.before_request
def before_request():
    """Initialize request context for AI telemetry"""
    g.start_time = time.time()
    g.correlation_id = str(uuid.uuid4())
    
    # Log request start for AI training
    StructuredLogger.log_event(
        "request_started",
        method=request.method,
        path=request.path,
        endpoint=request.endpoint,
        user_agent=request.headers.get('User-Agent', 'unknown'),
        content_length=request.content_length or 0
    )

@app.after_request  
def after_request(response):
    """Log request completion with AI-relevant metrics"""
    if hasattr(g, 'start_time'):
        duration = time.time() - g.start_time
        
        # Log request completion for AI training
        StructuredLogger.log_event(
            "request_completed",
            method=request.method,
            path=request.path,
            endpoint=request.endpoint,
            status_code=response.status_code,
            duration_seconds=duration,
            duration_ms=duration * 1000,
            response_size=response.content_length or 0,
            success=200 <= response.status_code < 400
        )
    
    return response

# Define root route
@app.route("/")
def root():
    with tracer.start_as_current_span("root_endpoint") as span:
        correlation_id = StructuredLogger.get_correlation_id()
        
        # Enhanced span attributes with correlation
        span.set_attribute("correlation_id", correlation_id)
        span.set_attribute("slo.sim_bad", SIM_BAD)
        span.set_attribute("slo.error_rate", ERROR_RATE)
        span.set_attribute("service.version", SERVICE_VERSION)
        span.set_attribute("version.label", VERSION_LABEL)
        
        # Simulate latency
        latency = simulate_latency()
        span.set_attribute("response.latency_ms", latency * 1000)
        
        # Log business event for AI training
        StructuredLogger.log_event(
            "business_event",
            event_name="page_view",
            page="root",
            latency_ms=latency * 1000,
            latency_category="fast" if latency < 0.2 else "slow" if latency < 1.0 else "very_slow"
        )
        
        # Check if service should fail
        health_result = health_sim()
        if not health_result:
            span.set_status(Status(StatusCode.ERROR, "Service simulation failure"))
            span.set_attribute("response.status", "error")
            
            # Log SLO violation for AI training
            StructuredLogger.log_event(
                "slo_violation",
                violation_type="service_failure",
                endpoint="root",
                latency_ms=latency * 1000,
                expected_success=True,
                actual_success=False
            )
            
            return f"Service Unavailable [{VERSION_LABEL}]", 503
        
        span.set_attribute("response.status", "success")
        
        # Log successful operation for AI training
        StructuredLogger.log_event(
            "operation_success",
            operation="root_endpoint",
            latency_ms=latency * 1000,
            performance_category="normal"
        )
        
        return f"Application is running! [{VERSION_LABEL}] (Response time: {latency:.2f}s)"

# K8s health endpoint
@app.route("/health")
def health():
    with tracer.start_as_current_span("health_check") as span:
        correlation_id = StructuredLogger.get_correlation_id()
        span.set_attribute("correlation_id", correlation_id)
        
        # Simulate health check with randomizer
        is_healthy = health_sim()
        span.set_attribute("health.status", "healthy" if is_healthy else "unhealthy")
        span.set_attribute("slo.sim_bad", SIM_BAD)
        span.set_attribute("service.version", SERVICE_VERSION)
        span.set_attribute("version.label", VERSION_LABEL)
        
        # Log health check event for AI training
        StructuredLogger.log_event(
            "health_check",
            is_healthy=is_healthy,
            health_status="healthy" if is_healthy else "unhealthy",
            endpoint="health"
        )
        
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
        correlation_id = StructuredLogger.get_correlation_id()
        span.set_attribute("correlation_id", correlation_id)
        
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
            
            # Log API failure for AI training
            StructuredLogger.log_event(
                "api_failure",
                endpoint="users",
                failure_reason="service_unavailable",
                latency_ms=latency * 1000,
                expected_users_count=3,
                actual_users_count=0
            )
            
            return f"Service Unavailable [{VERSION_LABEL}]", 503
        
        users_data = {"users": [
            {"id": 1, "name": "John Doe", "email": "john@example.com"},
            {"id": 2, "name": "Jane Smith", "email": "jane@example.com"},
            {"id": 3, "name": "Bob Johnson", "email": "bob@example.com"}
        ], "response_time": f"{latency:.2f}s"}
        
        span.set_attribute("response.status", "success")
        span.set_attribute("users.count", len(users_data["users"]))
        
        # Log successful API call for AI training
        StructuredLogger.log_event(
            "api_success",
            endpoint="users",
            users_count=len(users_data["users"]),
            latency_ms=latency * 1000,
            data_size_bytes=len(str(users_data))
        )
        
        return users_data


# AI Training Data endpoint to show structured logging in action
@app.route("/ai-logs-demo")
def ai_logs_demo():
    """Demonstrates structured logging output for AI training"""
    with tracer.start_as_current_span("ai_logs_demo") as span:
        correlation_id = StructuredLogger.get_correlation_id()
        span.set_attribute("correlation_id", correlation_id)
        
        # Generate sample structured logs for demonstration
        StructuredLogger.log_event(
            "demo_event",
            event_category="ai_training_demo",
            sample_data={
                "user_action": "view_logs",
                "performance_metrics": {
                    "cpu_usage": random.uniform(10, 80),
                    "memory_usage": random.uniform(100, 500),
                    "latency_p95": random.uniform(50, 200)
                },
                "business_context": {
                    "feature_flags": ["new_ui", "enhanced_logging"],
                    "user_segment": "developer",
                    "experiment_variant": "control"
                }
            }
        )
        
        return {
            "message": "Structured logging demo completed",
            "correlation_id": correlation_id,
            "instructions": "Check your application logs for JSON-formatted structured logs that are AI-ready",
            "log_format": {
                "timestamp": "ISO 8601 format",
                "event_type": "Categorized event types for ML",
                "correlation_id": "Request correlation across services",
                "trace_id": "OpenTelemetry trace correlation", 
                "service": "Service metadata",
                "slo_config": "SLO simulation configuration",
                "custom_data": "Event-specific data for AI training"
            }
        }


# SLO Simulation Functions
def simulate_latency():
    """Simulate network latency issues"""
    with tracer.start_as_current_span("simulate_latency") as span:
        if LATENCY_SIMULATION and SIM_BAD:
            latency = random.uniform(0.1, MAX_LATENCY)
            span.set_attribute("latency.simulated", True)
            span.set_attribute("latency.duration_seconds", latency)
            
            # Log latency simulation for AI training
            StructuredLogger.log_event(
                "latency_simulation",
                simulated=True,
                latency_seconds=latency,
                latency_ms=latency * 1000,
                latency_category="fast" if latency < 0.2 else "slow" if latency < 1.0 else "very_slow",
                max_configured_latency=MAX_LATENCY
            )
            
            time.sleep(latency)
            return latency
        
        span.set_attribute("latency.simulated", False)
        baseline_latency = 0.01  # Small baseline latency
        
        # Log normal operation for AI training
        StructuredLogger.log_event(
            "latency_simulation", 
            simulated=False,
            latency_seconds=baseline_latency,
            latency_ms=baseline_latency * 1000,
            latency_category="fast"
        )
        
        return baseline_latency

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
            
            # Log outage for AI training
            StructuredLogger.log_event(
                "system_failure",
                failure_type="outage",
                severity="critical",
                sim_bad_enabled=SIM_BAD,
                outage_simulation_enabled=OUTAGE_SIMULATION
            )
            
            return False
        
        # Check for error rate simulation
        if simulate_error_rate():
            span.set_attribute("failure.type", "error_rate")
            
            # Log error rate failure for AI training  
            StructuredLogger.log_event(
                "system_failure",
                failure_type="error_rate",
                severity="medium",
                configured_error_rate=ERROR_RATE,
                sim_bad_enabled=SIM_BAD
            )
            
            return False
        
        span.set_attribute("failure.type", "none")
        
        # Log healthy operation for AI training
        StructuredLogger.log_event(
            "system_health",
            health_status="healthy",
            sim_bad_enabled=SIM_BAD,
            all_checks_passed=True
        )
        
        return True

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000, debug=False)