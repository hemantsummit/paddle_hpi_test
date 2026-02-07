#!/bin/bash
# Build GPU Docker image for PaddleX OCR
# Run on g4dn.xlarge (Tesla T4) or any NVIDIA GPU instance
set -e

IMAGE_NAME="${IMAGE_NAME:-paddleocr-api-gpu}"

echo "=== Building GPU Image ==="
echo "Image: $IMAGE_NAME"
echo "Requires: NVIDIA Docker runtime (nvidia-container-toolkit)"
echo ""

docker build -f Dockerfile.gpu -t "$IMAGE_NAME" .

echo ""
echo "=== Build Complete ==="
echo "Run with: ./run-gpu.sh"
echo "Or: docker run --gpus all -p 8000:8000 $IMAGE_NAME"
