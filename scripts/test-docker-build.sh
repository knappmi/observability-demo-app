#!/bin/bash

# Local Docker Build and Test Script
# This script builds the Docker image locally and runs basic tests

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_color $GREEN "🚀 Local Docker Build and Test Script"
echo ""

# Generate version information
print_color $YELLOW "📋 Generating version information..."
if [[ -f "scripts/generate-version.sh" ]]; then
    source <(./scripts/generate-version.sh -f export)
    echo "   Version: $VERSION"
    echo "   Label: $VERSION_LABEL"
else
    # Fallback if script doesn't exist
    VERSION="1.0.0-local"
    VERSION_LABEL="v1.0.0-local-test"
    COMMIT_SHA="local"
    BUILD_TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    print_color $YELLOW "   Using fallback version: $VERSION"
fi

# Build Docker image
print_color $YELLOW "🐳 Building Docker image..."
docker build \
    --build-arg VERSION="$VERSION" \
    --build-arg VERSION_LABEL="$VERSION_LABEL" \
    --build-arg COMMIT_SHA="$COMMIT_SHA" \
    --build-arg BUILD_TIMESTAMP="$BUILD_TIMESTAMP" \
    -t observability-demo:$VERSION \
    -t observability-demo:latest \
    ./web-app

print_color $GREEN "✅ Docker image built successfully!"

# Test the image
print_color $YELLOW "🧪 Testing the Docker image..."

# Start container in background
CONTAINER_ID=$(docker run -d -p 5000:5000 \
    -e VERSION_LABEL="$VERSION_LABEL" \
    -e OTEL_SERVICE_VERSION="$VERSION" \
    -e SIM_BAD=false \
    observability-demo:$VERSION)

print_color $YELLOW "   Container started: $CONTAINER_ID"

# Wait for container to be ready
print_color $YELLOW "   Waiting for container to be ready..."
sleep 5

# Test endpoints
print_color $YELLOW "   Testing endpoints..."

# Test health endpoint
if curl -f -s http://localhost:5000/health > /dev/null; then
    print_color $GREEN "   ✅ Health endpoint: OK"
else
    print_color $RED "   ❌ Health endpoint: FAILED"
fi

# Test root endpoint
if curl -f -s http://localhost:5000/ > /dev/null; then
    print_color $GREEN "   ✅ Root endpoint: OK"
else
    print_color $RED "   ❌ Root endpoint: FAILED"
fi

# Test version endpoint
VERSION_RESPONSE=$(curl -s http://localhost:5000/version)
if [[ $? -eq 0 ]]; then
    print_color $GREEN "   ✅ Version endpoint: OK"
    echo "   Response: $VERSION_RESPONSE"
else
    print_color $RED "   ❌ Version endpoint: FAILED"
fi

# Cleanup
print_color $YELLOW "🧹 Cleaning up..."
docker stop $CONTAINER_ID > /dev/null
docker rm $CONTAINER_ID > /dev/null

print_color $GREEN "✅ All tests completed!"
echo ""
print_color $YELLOW "📝 To run the container manually:"
echo "   docker run -p 5000:5000 observability-demo:$VERSION"
echo ""
print_color $YELLOW "📝 To test with SLO simulation:"
echo "   docker run -p 5000:5000 -e SIM_BAD=true -e ERROR_RATE=0.2 observability-demo:$VERSION"
