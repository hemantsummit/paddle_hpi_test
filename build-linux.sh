#!/bin/bash
# Build on native Linux x86_64 for optimal performance.
# HPI (OpenVINO/ONNX) installs successfully; PaddleX uses high-performance backend.
# Run this on a Linux x86_64 machine (cloud VM, bare metal, etc.).
set -e
docker build -t paddleocr-api:latest .
echo "Built paddleocr-api:latest (with HPI). Run: docker run -p 8000:8000 paddleocr-api:latest"
