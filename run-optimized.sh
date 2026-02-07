#!/bin/bash
# Run Docker container with optimized config
set -e

IMAGE_NAME="${IMAGE_NAME:-paddleocr-api}"
CONTAINER_NAME="${CONTAINER_NAME:-paddleocr-api}"
PORT="${PORT:-8000}"

# Performance tuning parameters (can be overridden via environment variables)
CPU_THREADS="${PADDLE_CPU_THREADS:-$(nproc 2>/dev/null || echo 8)}"
MKLDNN_CACHE="${PADDLE_MKLDNN_CACHE_CAPACITY:-30}"
ENABLE_MKLDNN="${FLAGS_use_mkldnn:-1}"
DET_LIMIT_SIDE_LEN="${PADDLE_DET_LIMIT_SIDE_LEN:-768}"
PRECISION="${PADDLE_PRECISION:-fp16}"
HPI_BACKEND="${PADDLE_HPI_BACKEND:-paddle}"

# Config file paths
CONFIG_DIR="./config"
LOCAL_CONFIG="${CONFIG_DIR}/ocr_config.yaml"
CONTAINER_CONFIG="/app/ocr_config.yaml"

echo "=== Starting Container ==="
echo "Image: $IMAGE_NAME"
echo "Container: $CONTAINER_NAME"
echo "Port: $PORT"
echo ""

# Check if image exists
if ! docker images --format '{{.Repository}}' | grep -q "^${IMAGE_NAME}$"; then
    echo "Error: Image '$IMAGE_NAME' not found!"
    echo "Please build the image first: ./build-optimized.sh"
    exit 1
fi

# Check if config exists
VOLUME_MOUNT=""
if [ -f "$LOCAL_CONFIG" ]; then
    VOLUME_MOUNT="-v $(pwd)/$CONFIG_DIR/ocr_config.yaml:$CONTAINER_CONFIG:ro"
    echo "Using optimized config: $LOCAL_CONFIG"
else
    echo "Warning: Config file not found: $LOCAL_CONFIG"
    echo "Using default config from image"
    echo "To generate config, run: ./build-optimized.sh"
fi

# Stop existing container if running
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Stopping existing container..."
    docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
    docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true
fi

# Run container with optimized config and performance settings
echo ""
echo "Starting container with performance settings:"
echo "  CPU Threads: $CPU_THREADS"
echo "  MKLDNN Cache: $MKLDNN_CACHE"
echo "  MKLDNN Enabled: $ENABLE_MKLDNN"
echo "  Det Limit Side Len: $DET_LIMIT_SIDE_LEN"
echo "  Precision: $PRECISION"
echo "  HPI Backend: $HPI_BACKEND (paddle|openvino|onnxruntime|auto)"
echo ""

docker run -d \
  --name "$CONTAINER_NAME" \
  -p "$PORT:8000" \
  -e PADDLE_CPU_THREADS="$CPU_THREADS" \
  -e PADDLE_MKLDNN_CACHE_CAPACITY="$MKLDNN_CACHE" \
  -e FLAGS_use_mkldnn="$ENABLE_MKLDNN" \
  -e PADDLE_DET_LIMIT_SIDE_LEN="$DET_LIMIT_SIDE_LEN" \
  -e PADDLE_PRECISION="$PRECISION" \
  -e PADDLE_HPI_BACKEND="$HPI_BACKEND" \
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
echo "Useful commands:"
echo "  View logs: docker logs -f $CONTAINER_NAME"
echo "  Stop: docker stop $CONTAINER_NAME"
echo "  Remove: docker rm $CONTAINER_NAME"
echo "  Test: curl -X POST http://localhost:$PORT/ocr -F 'image=@your_image.png'"
