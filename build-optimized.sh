#!/bin/bash
# Build Docker image and generate optimized OCR config
set -e

IMAGE_NAME="${IMAGE_NAME:-paddleocr-api}"

# Performance tuning parameters (can be overridden via environment variables)
CPU_THREADS="${PADDLE_CPU_THREADS:-$(nproc 2>/dev/null || echo 8)}"
MKLDNN_CACHE="${PADDLE_MKLDNN_CACHE_CAPACITY:-30}"
ENABLE_MKLDNN="${FLAGS_use_mkldnn:-1}"

# Platform detection for local ARM64 builds (e.g., Apple Silicon)
PLATFORM_FLAG=""
if [ "$(uname -m)" = "arm64" ] || [ "$(uname -m)" = "aarch64" ]; then
  PLATFORM_FLAG="--platform linux/amd64"
  echo "Detected ARM64 architecture, using --platform linux/amd64"
fi

# Config file paths
CONFIG_DIR="./config"
LOCAL_CONFIG="${CONFIG_DIR}/ocr_config.yaml"

echo "=== Building Docker Image ==="
echo "Image name: $IMAGE_NAME"
if [ -n "$PLATFORM_FLAG" ]; then
  echo "Platform: linux/amd64 (for ARM64 host)"
fi
echo ""

docker build $PLATFORM_FLAG -t "$IMAGE_NAME" .

echo ""
echo "=== Generating Optimized Config ==="
echo "CPU Threads: $CPU_THREADS"
echo "MKLDNN Cache Capacity: $MKLDNN_CACHE"
echo "MKLDNN Enabled: $ENABLE_MKLDNN"
echo ""

# Create config directory
mkdir -p "$CONFIG_DIR"

# Run container to generate optimized config
echo "Generating config in temporary container..."
docker run --rm $PLATFORM_FLAG \
  -e PADDLE_CPU_THREADS="$CPU_THREADS" \
  -e PADDLE_MKLDNN_CACHE_CAPACITY="$MKLDNN_CACHE" \
  -e FLAGS_use_mkldnn="$ENABLE_MKLDNN" \
  -v "$(pwd)/$CONFIG_DIR:/config" \
  "$IMAGE_NAME" \
  python generate_optimized_config.py \
    --cpu-threads "$CPU_THREADS" \
    --mkldnn-cache "$MKLDNN_CACHE" \
    $([ "$ENABLE_MKLDNN" = "1" ] && echo "--enable-mkldnn" || echo "--disable-mkldnn") \
    --output /config/ocr_config.yaml

if [ ! -f "$LOCAL_CONFIG" ]; then
    echo "Error: Config file was not generated!"
    exit 1
fi

echo ""
echo "=== Build Complete ==="
echo "✓ Image built: $IMAGE_NAME"
echo "✓ Config generated: $LOCAL_CONFIG"
echo ""
echo "Performance settings:"
echo "  CPU Threads: $CPU_THREADS"
echo "  MKLDNN Cache: $MKLDNN_CACHE"
echo "  MKLDNN Enabled: $ENABLE_MKLDNN"
echo ""
echo "Next step: Run './run-optimized.sh' to start the container"
