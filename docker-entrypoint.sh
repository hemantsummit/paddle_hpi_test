#!/bin/sh
# Start PaddleX serving in background, then ocr_api proxy
set -e

PADDLEX_PORT=8080

# Use custom config if present, else default OCR pipeline
if [ -f /app/ocr_config.yaml ]; then
  PIPELINE_ARG="/app/ocr_config.yaml"
else
  PIPELINE_ARG="OCR"
fi

# Use HPI only when ultra-infer-python is installed (native Linux x86_64)
if pip show ultra-infer-python >/dev/null 2>&1; then
  echo "Using HPI (high-performance backend)"
  HPIP_FLAG="--use_hpip"
else
  echo "Using Paddle Inference backend (HPI not available)"
  HPIP_FLAG=""
fi

paddlex --serve --pipeline "$PIPELINE_ARG" --device cpu $HPIP_FLAG --port "$PADDLEX_PORT" --host 0.0.0.0 &
PADDLEX_PID=$!

echo "Waiting for PaddleX serving on port $PADDLEX_PORT..."
for i in $(seq 1 60); do
  if curl -sf "http://127.0.0.1:$PADDLEX_PORT/docs" >/dev/null 2>&1; then
    echo "PaddleX ready."
    break
  fi
  if [ $i -eq 60 ]; then
    echo "PaddleX failed to start."
    kill $PADDLEX_PID 2>/dev/null || true
    exit 1
  fi
  sleep 2
done

export PADDLEX_SERVING_URL="http://127.0.0.1:$PADDLEX_PORT"
exec python ocr_api.py
