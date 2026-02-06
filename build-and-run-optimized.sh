#!/bin/bash
# Build Docker image, generate optimized config, and run container
set -e

IMAGE_NAME="${IMAGE_NAME:-paddleocr-api}"
CONTAINER_NAME="${CONTAINER_NAME:-paddleocr-api}"
PORT="${PORT:-8000}"

# Performance tuning parameters (can be overridden via environment variables)
CPU_THREADS="${PADDLE_CPU_THREADS:-$(nproc 2>/dev/null || echo 8)}"
MKLDNN_CACHE="${PADDLE_MKLDNN_CACHE_CAPACITY:-30}"
ENABLE_MKLDNN="${FLAGS_use_mkldnn:-1}"

# Config file paths
CONFIG_DIR="./config"
LOCAL_CONFIG="${CONFIG_DIR}/ocr_config.yaml"
CONTAINER_CONFIG="/app/ocr_config.yaml"

# Platform detection for local ARM64 builds (e.g., Apple Silicon)
PLATFORM_FLAG=""
if [ "$(uname -m)" = "arm64" ] || [ "$(uname -m)" = "aarch64" ]; then
  PLATFORM_FLAG="--platform linux/amd64"
  echo "Detected ARM64 architecture, using --platform linux/amd64"
fi

echo "=== Building Docker Image ==="
echo "Image name: $IMAGE_NAME"
if [ -n "$PLATFORM_FLAG" ]; then
  echo "Platform: linux/amd64 (for ARM64 host)"
fi
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
    echo "Warning: Config file not generated. Using default config."
    LOCAL_CONFIG=""
fi

echo ""
echo "=== Starting Container ==="
echo "Container name: $CONTAINER_NAME"
echo "Port: $PORT"
echo ""

# Stop existing container if running
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Stopping existing container..."
    docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
    docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true
fi

# Run container with optimized config and performance settings
VOLUME_MOUNT=""
if [ -f "$LOCAL_CONFIG" ]; then
    VOLUME_MOUNT="-v $(pwd)/$CONFIG_DIR/ocr_config.yaml:$CONTAINER_CONFIG:ro"
    echo "Using optimized config: $LOCAL_CONFIG"
else
    echo "Using default config from image"
fi

docker run -d \
  --name "$CONTAINER_NAME" \
  -p "$PORT:8000" \
  -e PADDLE_CPU_THREADS="$CPU_THREADS" \
  -e PADDLE_MKLDNN_CACHE_CAPACITY="$MKLDNN_CACHE" \
  -e FLAGS_use_mkldnn="$ENABLE_MKLDNN" \
  $VOLUME_MOUNT \
  "$IMAGE_NAME"

echo ""
echo "=== Container Started ==="
echo "Waiting for services to be ready..."
sleep 5

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Error: Container failed to start"
    echo "Checking logs..."
    docker logs "$CONTAINER_NAME"
    exit 1
fi

# Health check
echo "Checking health..."
for i in {1..30}; do
    if curl -sf "http://localhost:$PORT/health" >/dev/null 2>&1; then
        echo "✓ Service is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "Warning: Service may not be ready yet. Check logs with: docker logs $CONTAINER_NAME"
    else
        sleep 2
    fi
done

echo ""
echo "=== Service Information ==="
echo "API URL: http://localhost:$PORT"
echo "Health check: http://localhost:$PORT/health"
echo "API docs: http://localhost:$PORT/docs"
echo ""
echo "Performance settings:"
echo "  CPU Threads: $CPU_THREADS"
echo "  MKLDNN Cache: $MKLDNN_CACHE"
echo "  MKLDNN Enabled: $ENABLE_MKLDNN"
echo ""
echo "Useful commands:"
echo "  View logs: docker logs -f $CONTAINER_NAME"
echo "  Stop: docker stop $CONTAINER_NAME"
echo "  Remove: docker rm $CONTAINER_NAME"
echo "  Test: curl -X POST http://localhost:$PORT/ocr -F 'image=@your_image.png'"
