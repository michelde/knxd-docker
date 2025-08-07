#!/bin/bash

# Build script for knxd-docker
# Usage: ./scripts/build.sh [KNXD_VERSION] [OPTIONS]

set -euo pipefail

# Default values
KNXD_VERSION="${1:-0.14.66}"
IMAGE_NAME="${IMAGE_NAME:-knxd}"
REGISTRY="${REGISTRY:-}"
PUSH="${PUSH:-false}"
PLATFORMS="${PLATFORMS:-linux/amd64}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [KNXD_VERSION] [OPTIONS]

Arguments:
  KNXD_VERSION    Version of knxd to build (default: 0.14.66)

Environment Variables:
  IMAGE_NAME      Name of the Docker image (default: knxd)
  REGISTRY        Docker registry prefix (optional)
  PUSH            Push to registry after build (default: false)
  PLATFORMS       Target platforms for buildx (default: linux/amd64)

Examples:
  # Basic build
  $0 0.14.66

  # Build with custom image name
  IMAGE_NAME=my-knxd $0 0.14.66

  # Multi-platform build and push
  REGISTRY=myregistry.com/myuser PUSH=true PLATFORMS=linux/amd64,linux/arm64 $0 0.14.66

  # Show this help
  $0 --help
EOF
}

# Check for help flag
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    show_usage
    exit 0
fi

# Validate knxd version format
if ! [[ "$KNXD_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "Invalid KNXD_VERSION format: $KNXD_VERSION"
    log_info "Expected format: x.y.z (e.g., 0.14.66)"
    exit 1
fi

# Generate build metadata
BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
VCS_REF=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# Construct image tags
FULL_IMAGE_NAME="${REGISTRY:+$REGISTRY/}${IMAGE_NAME}"
TAGS=(
    "${FULL_IMAGE_NAME}:${KNXD_VERSION}"
    "${FULL_IMAGE_NAME}:latest"
)

log_info "Starting knxd-docker build"
log_info "KNXD Version: $KNXD_VERSION"
log_info "Image Name: $FULL_IMAGE_NAME"
log_info "Build Date: $BUILD_DATE"
log_info "VCS Ref: $VCS_REF"
log_info "Platforms: $PLATFORMS"

# Check if multi-platform build is requested
if [[ "$PLATFORMS" == *","* ]]; then
    log_info "Multi-platform build detected, using buildx"
    
    # Check if buildx is available
    if ! docker buildx version >/dev/null 2>&1; then
        log_error "Docker buildx is required for multi-platform builds"
        exit 1
    fi
    
    # Create builder if it doesn't exist
    BUILDER_NAME="knxd-builder"
    if ! docker buildx inspect "$BUILDER_NAME" >/dev/null 2>&1; then
        log_info "Creating buildx builder: $BUILDER_NAME"
        docker buildx create --name "$BUILDER_NAME" --use
        docker buildx inspect "$BUILDER_NAME" --bootstrap
    else
        docker buildx use "$BUILDER_NAME"
    fi
    
    # Build command for multi-platform
    BUILD_CMD="docker buildx build"
    BUILD_ARGS="--platform=$PLATFORMS"
    
    if [[ "$PUSH" == "true" ]]; then
        BUILD_ARGS="$BUILD_ARGS --push"
    else
        BUILD_ARGS="$BUILD_ARGS --load"
    fi
else
    # Single platform build
    BUILD_CMD="docker build"
    BUILD_ARGS=""
fi

# Add tags to build command
for tag in "${TAGS[@]}"; do
    BUILD_ARGS="$BUILD_ARGS -t $tag"
done

# Add build arguments
BUILD_ARGS="$BUILD_ARGS --build-arg KNXD_VERSION=$KNXD_VERSION"
BUILD_ARGS="$BUILD_ARGS --build-arg BUILD_DATE=$BUILD_DATE"
BUILD_ARGS="$BUILD_ARGS --build-arg VCS_REF=$VCS_REF"

# Execute build
log_info "Executing build command..."
eval "$BUILD_CMD $BUILD_ARGS ."

if [[ $? -eq 0 ]]; then
    log_success "Build completed successfully!"
    
    # Show image information
    if [[ "$PLATFORMS" != *","* ]]; then
        log_info "Image size:"
        docker images "${FULL_IMAGE_NAME}:${KNXD_VERSION}" --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}"
    fi
    
    # Push single-platform images if requested
    if [[ "$PUSH" == "true" && "$PLATFORMS" != *","* ]]; then
        log_info "Pushing images to registry..."
        for tag in "${TAGS[@]}"; do
            docker push "$tag"
        done
        log_success "Images pushed successfully!"
    fi
else
    log_error "Build failed!"
    exit 1
fi

log_success "Build process completed!"
