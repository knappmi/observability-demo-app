#!/bin/bash

# Feature Branch Versioning Script
# This script generates version information for feature branches and development

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to show usage
show_usage() {
    echo "Feature Branch Versioning Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -b, --branch BRANCH     Specify branch name (default: current git branch)"
    echo "  -v, --base-version VER  Specify base version (default: 1.0.0)"
    echo "  -f, --format FORMAT     Output format: env|json|yaml|export (default: env)"
    echo "  -o, --output FILE       Output to file instead of stdout"
    echo "  --show-docker-tags      Show suggested Docker tags"
    echo "  --show-k8s-env          Show Kubernetes environment variables"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Generate version for current branch"
    echo "  $0 -b feature/user-auth             # Generate version for specific branch"
    echo "  $0 -f json -o version.json          # Output JSON to file"
    echo "  $0 --show-docker-tags               # Show Docker tag suggestions"
    echo "  $0 --show-k8s-env                   # Show K8s environment variables"
}

# Default values
BRANCH_NAME=""
BASE_VERSION="1.0.0"
OUTPUT_FORMAT="env"
OUTPUT_FILE=""
SHOW_DOCKER_TAGS=false
SHOW_K8S_ENV=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -b|--branch)
            BRANCH_NAME="$2"
            shift 2
            ;;
        -v|--base-version)
            BASE_VERSION="$2"
            shift 2
            ;;
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --show-docker-tags)
            SHOW_DOCKER_TAGS=true
            shift
            ;;
        --show-k8s-env)
            SHOW_K8S_ENV=true
            shift
            ;;
        *)
            print_color $RED "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate output format
case $OUTPUT_FORMAT in
    env|json|yaml|export) ;;
    *)
        print_color $RED "Invalid output format: $OUTPUT_FORMAT"
        print_color $YELLOW "Valid formats: env, json, yaml, export"
        exit 1
        ;;
esac

# Check if we're in a git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    print_color $RED "Error: Not in a git repository"
    exit 1
fi

# Get branch name if not specified
if [[ -z "$BRANCH_NAME" ]]; then
    BRANCH_NAME=$(git branch --show-current)
    if [[ -z "$BRANCH_NAME" ]]; then
        print_color $RED "Error: Could not determine current branch"
        exit 1
    fi
fi

# Get git information
COMMIT_SHA=$(git rev-parse HEAD | cut -c1-7)
COMMIT_SHA_FULL=$(git rev-parse HEAD)
COMMIT_COUNT=$(git rev-list --count HEAD)
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
IS_DIRTY=$(git diff --quiet && echo "false" || echo "true")
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")

# Normalize branch name for version (remove special characters)
BRANCH_NORMALIZED=$(echo "$BRANCH_NAME" | sed 's/[^a-zA-Z0-9._-]/-/g' | tr '[:upper:]' '[:lower:]')

# Determine version strategy based on branch name
case "$BRANCH_NAME" in
    main|master)
        VERSION="${BASE_VERSION}"
        VERSION_LABEL="v${BASE_VERSION}-main-${COMMIT_SHA}"
        DEPLOYMENT_TYPE="production"
        ENVIRONMENT="production"
        ;;
    develop|development)
        VERSION="${BASE_VERSION}-dev-${COMMIT_SHA}"
        VERSION_LABEL="v${BASE_VERSION}-dev-${COMMIT_SHA}"
        DEPLOYMENT_TYPE="development"
        ENVIRONMENT="development"
        ;;
    release/*)
        RELEASE_VERSION=$(echo "$BRANCH_NAME" | sed 's|release/||')
        VERSION="${RELEASE_VERSION}-rc-${COMMIT_SHA}"
        VERSION_LABEL="v${RELEASE_VERSION}-rc-${COMMIT_SHA}"
        DEPLOYMENT_TYPE="release-candidate"
        ENVIRONMENT="staging"
        ;;
    hotfix/*)
        HOTFIX_VERSION=$(echo "$BRANCH_NAME" | sed 's|hotfix/||')
        VERSION="${HOTFIX_VERSION}-hotfix-${COMMIT_SHA}"
        VERSION_LABEL="v${HOTFIX_VERSION}-hotfix-${COMMIT_SHA}"
        DEPLOYMENT_TYPE="hotfix"
        ENVIRONMENT="staging"
        ;;
    feature/*|feat/*)
        FEATURE_NAME=$(echo "$BRANCH_NAME" | sed 's|feature/||' | sed 's|feat/||')
        VERSION="${BASE_VERSION}-feat-${FEATURE_NAME}-${COMMIT_SHA}"
        VERSION_LABEL="v${BASE_VERSION}-feat-${FEATURE_NAME}-${COMMIT_SHA}"
        DEPLOYMENT_TYPE="feature"
        ENVIRONMENT="development"
        ;;
    *)
        VERSION="${BASE_VERSION}-${BRANCH_NORMALIZED}-${COMMIT_SHA}"
        VERSION_LABEL="v${BASE_VERSION}-${BRANCH_NORMALIZED}-${COMMIT_SHA}"
        DEPLOYMENT_TYPE="custom"
        ENVIRONMENT="development"
        ;;
esac

# Add dirty suffix if working tree is dirty
if [[ "$IS_DIRTY" == "true" ]]; then
    VERSION="${VERSION}-dirty"
    VERSION_LABEL="${VERSION_LABEL}-dirty"
fi

# Generate Docker tags
DOCKER_TAG_PRIMARY="${VERSION}"
DOCKER_TAG_BRANCH="${BRANCH_NORMALIZED}"
DOCKER_TAG_COMMIT="${COMMIT_SHA}"
DOCKER_TAG_LATEST_BRANCH="${BRANCH_NORMALIZED}-latest"

# Generate output based on format
generate_output() {
    case $OUTPUT_FORMAT in
        env)
            cat << EOF
# Version Information for Branch: $BRANCH_NAME
VERSION=$VERSION
VERSION_LABEL=$VERSION_LABEL
OTEL_SERVICE_VERSION=$VERSION
COMMIT_SHA=$COMMIT_SHA
COMMIT_SHA_FULL=$COMMIT_SHA_FULL
COMMIT_COUNT=$COMMIT_COUNT
BRANCH_NAME=$BRANCH_NAME
BRANCH_NORMALIZED=$BRANCH_NORMALIZED
DEPLOYMENT_TYPE=$DEPLOYMENT_TYPE
ENVIRONMENT=$ENVIRONMENT
BUILD_TIMESTAMP=$TIMESTAMP
IS_DIRTY=$IS_DIRTY
LAST_TAG=$LAST_TAG
DOCKER_TAG_PRIMARY=$DOCKER_TAG_PRIMARY
DOCKER_TAG_BRANCH=$DOCKER_TAG_BRANCH
DOCKER_TAG_COMMIT=$DOCKER_TAG_COMMIT
DOCKER_TAG_LATEST_BRANCH=$DOCKER_TAG_LATEST_BRANCH
EOF
            ;;
        export)
            cat << EOF
#!/bin/bash
# Export version information for Branch: $BRANCH_NAME
export VERSION="$VERSION"
export VERSION_LABEL="$VERSION_LABEL"
export OTEL_SERVICE_VERSION="$VERSION"
export COMMIT_SHA="$COMMIT_SHA"
export COMMIT_SHA_FULL="$COMMIT_SHA_FULL"
export COMMIT_COUNT="$COMMIT_COUNT"
export BRANCH_NAME="$BRANCH_NAME"
export BRANCH_NORMALIZED="$BRANCH_NORMALIZED"
export DEPLOYMENT_TYPE="$DEPLOYMENT_TYPE"
export ENVIRONMENT="$ENVIRONMENT"
export BUILD_TIMESTAMP="$TIMESTAMP"
export IS_DIRTY="$IS_DIRTY"
export LAST_TAG="$LAST_TAG"
export DOCKER_TAG_PRIMARY="$DOCKER_TAG_PRIMARY"
export DOCKER_TAG_BRANCH="$DOCKER_TAG_BRANCH"
export DOCKER_TAG_COMMIT="$DOCKER_TAG_COMMIT"
export DOCKER_TAG_LATEST_BRANCH="$DOCKER_TAG_LATEST_BRANCH"
EOF
            ;;
        json)
            cat << EOF
{
  "version": "$VERSION",
  "version_label": "$VERSION_LABEL",
  "otel_service_version": "$VERSION",
  "git": {
    "commit_sha": "$COMMIT_SHA",
    "commit_sha_full": "$COMMIT_SHA_FULL",
    "commit_count": $COMMIT_COUNT,
    "branch_name": "$BRANCH_NAME",
    "branch_normalized": "$BRANCH_NORMALIZED",
    "is_dirty": $IS_DIRTY,
    "last_tag": "$LAST_TAG"
  },
  "deployment": {
    "type": "$DEPLOYMENT_TYPE",
    "environment": "$ENVIRONMENT"
  },
  "build": {
    "timestamp": "$TIMESTAMP"
  },
  "docker_tags": {
    "primary": "$DOCKER_TAG_PRIMARY",
    "branch": "$DOCKER_TAG_BRANCH",
    "commit": "$DOCKER_TAG_COMMIT",
    "latest_branch": "$DOCKER_TAG_LATEST_BRANCH"
  }
}
EOF
            ;;
        yaml)
            cat << EOF
version: $VERSION
version_label: $VERSION_LABEL
otel_service_version: $VERSION
git:
  commit_sha: $COMMIT_SHA
  commit_sha_full: $COMMIT_SHA_FULL
  commit_count: $COMMIT_COUNT
  branch_name: $BRANCH_NAME
  branch_normalized: $BRANCH_NORMALIZED
  is_dirty: $IS_DIRTY
  last_tag: $LAST_TAG
deployment:
  type: $DEPLOYMENT_TYPE
  environment: $ENVIRONMENT
build:
  timestamp: $TIMESTAMP
docker_tags:
  primary: $DOCKER_TAG_PRIMARY
  branch: $DOCKER_TAG_BRANCH
  commit: $DOCKER_TAG_COMMIT
  latest_branch: $DOCKER_TAG_LATEST_BRANCH
EOF
            ;;
    esac
}

# Output to file or stdout
if [[ -n "$OUTPUT_FILE" ]]; then
    generate_output > "$OUTPUT_FILE"
    print_color $GREEN "Version information written to: $OUTPUT_FILE"
else
    generate_output
fi

# Show Docker tags if requested
if [[ "$SHOW_DOCKER_TAGS" == "true" ]]; then
    echo ""
    print_color $BLUE "🐳 Suggested Docker Tags:"
    echo "  Primary: $DOCKER_TAG_PRIMARY"
    echo "  Branch:  $DOCKER_TAG_BRANCH"
    echo "  Commit:  $DOCKER_TAG_COMMIT"
    echo "  Latest:  $DOCKER_TAG_LATEST_BRANCH"
    echo ""
    print_color $BLUE "🐳 Docker Build Commands:"
    echo "  docker build -t myregistry/observability-demo:$DOCKER_TAG_PRIMARY ."
    echo "  docker build -t myregistry/observability-demo:$DOCKER_TAG_BRANCH ."
    echo "  docker build -t myregistry/observability-demo:$DOCKER_TAG_COMMIT ."
fi

# Show Kubernetes environment variables if requested
if [[ "$SHOW_K8S_ENV" == "true" ]]; then
    echo ""
    print_color $BLUE "☸️  Kubernetes Environment Variables:"
    cat << EOF
        env:
        - name: VERSION_LABEL
          value: "$VERSION_LABEL"
        - name: OTEL_SERVICE_VERSION
          value: "$VERSION"
        - name: COMMIT_SHA
          value: "$COMMIT_SHA"
        - name: BRANCH_NAME
          value: "$BRANCH_NAME"
        - name: DEPLOYMENT_TYPE
          value: "$DEPLOYMENT_TYPE"
        - name: ENVIRONMENT
          value: "$ENVIRONMENT"
        - name: BUILD_TIMESTAMP
          value: "$TIMESTAMP"
EOF
fi

# Show summary if outputting to stdout
if [[ -z "$OUTPUT_FILE" && "$SHOW_DOCKER_TAGS" == "false" && "$SHOW_K8S_ENV" == "false" ]]; then
    echo ""
    print_color $GREEN "✅ Version generated for branch: $BRANCH_NAME"
    print_color $YELLOW "   Version: $VERSION"
    print_color $YELLOW "   Label:   $VERSION_LABEL"
    print_color $YELLOW "   Type:    $DEPLOYMENT_TYPE"
fi
