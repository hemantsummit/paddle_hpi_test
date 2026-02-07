#!/bin/sh
# GPU entrypoint - defaults only, no config generation
# PaddleX serving with --device gpu --use_hpip
set -e

PADDLEX_PORT=8080

# Default OCR pipeline (no custom config)
PIPELINE_ARG="OCR"

# HPI when available
if python3 -m pip show ultra-infer-python >/dev/null 2>&1; then
  echo "Using HPI (high-performance inference) on GPU"
  paddlex --serve --pipeline "$PIPELINE_ARG" --device gpu --use_hpip --port "$PADDLEX_PORT" --host 0.0.0.0 &
else
  echo "Using Paddle Inference backend on GPU"
  paddlex --serve --pipeline "$PIPELINE_ARG" --device gpu --port "$PADDLEX_PORT" --host 0.0.0.0 &
fi
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
exec python3 ocr_api.py
