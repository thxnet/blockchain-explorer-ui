#!/usr/bin/env bash
set -euo pipefail

REGISTRY="ghcr.io"
IMAGE_NAME="${REGISTRY}/thxnet/blockchain-explorer-ui"
PLATFORM="linux/amd64"

PUSH=false
TAG=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --push) PUSH=true; shift ;;
    --tag) TAG="$2"; shift 2 ;;
    --tag=*) TAG="${1#*=}"; shift ;;
    -h|--help)
      echo "Usage: $0 [--push] [--tag TAG]"
      echo "  --push       Push image to GHCR after building"
      echo "  --tag TAG    Custom tag (default: local-YYYYMMDD-SHORT_SHA)"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

if [[ -z "${TAG}" ]]; then
  TAG="local-$(date +%Y%m%d)-$(git rev-parse --short HEAD)"
fi

FULL_TAG="${IMAGE_NAME}:${TAG}"
echo "=== blockchain-explorer-ui Docker Build ==="
echo "Platform: ${PLATFORM}"
echo "Image:    ${FULL_TAG}"
echo "Push:     ${PUSH}"
echo ""

# Ensure submodules
if [[ ! -f polkadapt/package.json ]]; then
  echo ">>> Initializing git submodules..."
  git submodule update --init --recursive --depth=1
fi

# Dummy config (same as CI)
echo ">>> Creating dummy config files..."
mkdir -p src/assets
echo '{}' > src/assets/config.json
echo '<p>This is a test file.</p>' > src/assets/privacy-policy.html

# Login to GHCR if pushing
if [[ "${PUSH}" == "true" ]]; then
  echo ">>> Logging in to GHCR..."
  gh auth token | docker login "${REGISTRY}" \
    -u "$(gh api user --jq .login)" --password-stdin
fi

# Buildx builder
BUILDER_NAME="explorer-ui-builder"
if ! docker buildx inspect "${BUILDER_NAME}" >/dev/null 2>&1; then
  echo ">>> Creating buildx builder..."
  docker buildx create --name "${BUILDER_NAME}" --driver docker-container --use
else
  docker buildx use "${BUILDER_NAME}"
fi

# Build
BUILD_ARGS=(
  --platform "${PLATFORM}"
  --tag "${FULL_TAG}"
  --file Dockerfile
)

if [[ "${PUSH}" == "true" ]]; then
  BUILD_ARGS+=(--push --tag "${IMAGE_NAME}:latest")
else
  BUILD_ARGS+=(--load)
fi

echo ">>> Building..."
docker buildx build "${BUILD_ARGS[@]}" .

echo ""
echo "=== Done ==="
echo "Tagged: ${FULL_TAG}"
[[ "${PUSH}" == "true" ]] && echo "Pushed to: ${REGISTRY}"
