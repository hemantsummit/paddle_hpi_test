#!/bin/bash
# Run GPU container - requires nvidia-container-toolkit on host
# For g4dn.xlarge (Tesla T4) on Amazon Linux
# Config generated at runtime (not build). Optional: mount custom config.
set -e

IMAGE_NAME="${IMAGE_NAME:-paddleocr-api-gpu}"
CONTAINER_NAME="${CONTAINER_NAME:-paddleocr-api-gpu}"
PORT="${PORT:-8000}"

# Performance tuning parameters (can be overridden via environment variables)
CPU_THREADS="${PADDLE_CPU_THREADS:-10}"
MKLDNN_CACHE="${PADDLE_MKLDNN_CACHE_CAPACITY:-20}"
DET_LIMIT="${PADDLE_DET_LIMIT_SIDE_LEN:-960}"
PRECISION="${PADDLE_PRECISION:-fp16}"

# Config: optional mount (inline with CPU). If not mounted, config generated at runtime.
CONFIG_DIR="./config"
LOCAL_CONFIG="${CONFIG_DIR}/ocr_config.yaml"
CONTAINER_CONFIG="/app/ocr_config.yaml"

echo "=== Starting GPU Container ==="
echo "Container: $CONTAINER_NAME"
echo "Port: $PORT"
echo ""

# Check if image exists
if ! docker images --format '{{.Repository}}' | grep -q "^${IMAGE_NAME}$"; then
  echo "Error: Image '$IMAGE_NAME' not found!"
  echo "Please build first: ./build-gpu.sh"
  exit 1
fi

# Optional: mount custom config (if present). Else config generated at runtime.
VOLUME_MOUNT=""
if [ -f "$LOCAL_CONFIG" ]; then
  VOLUME_MOUNT="-v $(pwd)/$LOCAL_CONFIG:$CONTAINER_CONFIG:ro"
  echo "Using custom config: $LOCAL_CONFIG"
else
  echo "No custom config. Config will be generated at runtime."
fi

# Stop existing container if running
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "Stopping existing container..."
  docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
  docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true
fi

echo ""
echo "Performance settings:"
echo "  CPU Threads: $CPU_THREADS"
echo "  MKLDNN Cache: $MKLDNN_CACHE"
echo "  Det Limit Side Len: $DET_LIMIT"
echo "  Precision: $PRECISION"
echo ""

docker run -d \
  --name "$CONTAINER_NAME" \
  --gpus all \
  -p "$PORT:8000" \
  -e PADDLE_CPU_THREADS="$CPU_THREADS" \
  -e PADDLE_MKLDNN_CACHE_CAPACITY="$MKLDNN_CACHE" \
  -e FLAGS_use_mkldnn="${FLAGS_use_mkldnn:-1}" \
  -e PADDLE_DET_LIMIT_SIDE_LEN="$DET_LIMIT" \
  -e PADDLE_PRECISION="$PRECISION" \
  $VOLUME_MOUNT \
  "$IMAGE_NAME"

echo "Waiting for service..."
sleep 8
for i in $(seq 1 30); do
  if curl -sf "http://localhost:$PORT/health" >/dev/null 2>&1; then
    echo "✓ Service ready at http://localhost:$PORT"
    break
  fi
  [ $i -eq 30 ] && echo "Service may still be starting (first run downloads models). Check: docker logs $CONTAINER_NAME"
  sleep 2
done

echo ""
echo "API: http://localhost:$PORT"
echo "Docs: http://localhost:$PORT/docs"
echo "Test: curl -X POST http://localhost:$PORT/ocr -F 'image=@your_image.png'"
echo ""
echo "Useful commands:"
echo "  View logs: docker logs -f $CONTAINER_NAME"
echo "  Stop: docker stop $CONTAINER_NAME"
