#!/bin/bash

# Tag Creation Script for Bad Configuration Images
# Usage: ./create-bad-tag.sh <version> [config-type]
# 
# Examples:
#   ./create-bad-tag.sh 1.0.0 bad     # Creates v1.0.0-bad
#   ./create-bad-tag.sh 1.0.0 chaos   # Creates v1.0.0-chaos  
#   ./create-bad-tag.sh 1.0.0         # Creates v1.0.0 (normal)

set -e

VERSION=$1
CONFIG_TYPE=${2:-"normal"}

if [ -z "$VERSION" ]; then
    echo "❌ Error: Version is required"
    echo "Usage: $0 <version> [config-type]"
    echo ""
    echo "Examples:"
    echo "  $0 1.0.0 bad     # Creates v1.0.0-bad with 30% error rate"
    echo "  $0 1.0.0 chaos   # Creates v1.0.0-chaos with 50% error rate"
    echo "  $0 1.0.0         # Creates v1.0.0 with normal configuration"
    exit 1
fi

# Remove 'v' prefix if present
VERSION=$(echo "$VERSION" | sed 's/^v//')

# Determine tag name based on config type
case "$CONFIG_TYPE" in
    "bad")
        TAG="v${VERSION}-bad"
        echo "🚨 Creating BAD configuration tag: $TAG"
        echo "   - ERROR_RATE: 30%"
        echo "   - LATENCY_SIMULATION: enabled"
        echo "   - OUTAGE_SIMULATION: enabled"
        echo "   - MAX_LATENCY: 3.0s"
        ;;
    "chaos")
        TAG="v${VERSION}-chaos"
        echo "💥 Creating CHAOS configuration tag: $TAG"
        echo "   - ERROR_RATE: 50%"
        echo "   - LATENCY_SIMULATION: enabled"
        echo "   - OUTAGE_SIMULATION: enabled"
        echo "   - MAX_LATENCY: 5.0s"
        ;;
    "normal"|"")
        TAG="v${VERSION}"
        echo "✅ Creating NORMAL configuration tag: $TAG"
        echo "   - ERROR_RATE: 10%"
        echo "   - LATENCY_SIMULATION: disabled"
        echo "   - OUTAGE_SIMULATION: disabled"
        echo "   - MAX_LATENCY: 1.0s"
        ;;
    *)
        echo "❌ Error: Invalid config type '$CONFIG_TYPE'"
        echo "Valid types: normal, bad, chaos"
        exit 1
        ;;
esac

echo ""
echo "📋 This will:"
echo "   1. Create git tag: $TAG"
echo "   2. Push to origin"
echo "   3. Trigger GitHub Actions build"
echo "   4. Publish to DockerHub and GHCR"
echo ""

# Check if tag already exists
if git tag -l | grep -q "^$TAG$"; then
    echo "⚠️  Warning: Tag $TAG already exists!"
    echo ""
    read -p "Do you want to delete the existing tag and recreate it? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🗑️  Deleting existing tag..."
        git tag -d "$TAG" || true
        git push origin ":refs/tags/$TAG" || true
    else
        echo "❌ Aborted"
        exit 1
    fi
fi

# Confirm action
read -p "Do you want to proceed? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Aborted"
    exit 1
fi

# Create and push tag
echo "🏷️  Creating tag $TAG..."
git tag "$TAG"

echo "📤 Pushing tag to origin..."
git push origin "$TAG"

echo ""
echo "🎉 Success! Tag $TAG has been created and pushed."
echo ""
echo "📊 Monitor the build progress:"
echo "   GitHub Actions: https://github.com/knappmi/observability-demo-app/actions"
echo ""
echo "📦 Once built, images will be available at:"
echo "   DockerHub: knappmi14/observability-demo-app:$TAG"
echo "   GHCR: ghcr.io/knappmi/observability-demo-app:$TAG"
echo ""

if [ "$CONFIG_TYPE" = "bad" ] || [ "$CONFIG_TYPE" = "chaos" ]; then
    echo "⚠️  WARNING: This image contains BAD SLO configuration!"
    echo "   Only use for testing and demonstration purposes."
    echo "   Never deploy in production environments."
fi

echo ""
echo "🚀 You can test locally once the build completes:"
echo "   docker run -p 5000:5000 knappmi14/observability-demo-app:$TAG"
echo "   curl http://localhost:5000/slo-config"
