#!/bin/bash
# Run GPU container - requires nvidia-container-toolkit on host
# For g4dn.xlarge (Tesla T4) on Amazon Linux
set -e

IMAGE_NAME="${IMAGE_NAME:-paddleocr-api-gpu}"
CONTAINER_NAME="${CONTAINER_NAME:-paddleocr-api-gpu}"
PORT="${PORT:-8000}"

# Stop existing container
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "Stopping existing container..."
  docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
  docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true
fi

echo "=== Starting GPU Container ==="
echo "Container: $CONTAINER_NAME"
echo "Port: $PORT"
echo ""

docker run -d \
  --name "$CONTAINER_NAME" \
  --gpus all \
  -p "$PORT:8000" \
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
