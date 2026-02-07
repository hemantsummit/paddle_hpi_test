#!/bin/sh
# GPU entrypoint - custom config support, config generated at runtime (not build)
# PaddleX serving with --device gpu --use_hpip
# Inline with CPU setup: custom config, update_config, verify_config
set -e

PADDLEX_PORT=8080

# Performance tuning: auto-detect or use env vars (GPU: precision, det_limit, etc.)
CPU_THREADS=${PADDLE_CPU_THREADS:-10}
MKLDNN_CACHE=${PADDLE_MKLDNN_CACHE_CAPACITY:-20}
DET_LIMIT=${PADDLE_DET_LIMIT_SIDE_LEN:-960}
PRECISION=${PADDLE_PRECISION:-fp16}

# Export for config scripts (GPU mode)
export PADDLE_CPU_THREADS=$CPU_THREADS
export PADDLE_MKLDNN_CACHE_CAPACITY=$MKLDNN_CACHE
export FLAGS_use_mkldnn=${FLAGS_use_mkldnn:-1}
export PADDLE_DET_LIMIT_SIDE_LEN=$DET_LIMIT
export PADDLE_PRECISION=$PRECISION
export PADDLE_USE_GPU=1
# Skip model hoster connectivity check during config generation (speeds up startup)
export PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK=True

echo "=== Performance Configuration (GPU) ==="
echo "CPU Threads: $CPU_THREADS"
echo "MKLDNN Cache Capacity: $MKLDNN_CACHE"
echo "Det Limit Side Len: $DET_LIMIT"
echo "Precision: $PRECISION"
echo "================================"

# Custom config: use if present, else generate at runtime
if [ -f /app/ocr_config.yaml ]; then
  PIPELINE_ARG="/app/ocr_config.yaml"
  echo "Using custom config: /app/ocr_config.yaml"
  echo "Updating config with performance settings..."
  python3 update_config.py /app/ocr_config.yaml || echo "Warning: Could not update config file"
  python3 verify_config.py /app/ocr_config.yaml || true
else
  echo "Generating config at runtime (no pre-built config)..."
  python3 generate_optimized_config.py \
    --use-gpu \
    --cpu-threads "$CPU_THREADS" \
    --mkldnn-cache "$MKLDNN_CACHE" \
    --det-limit-side-len "$DET_LIMIT" \
    --precision "$PRECISION" \
    --enable-mkldnn \
    --output /app/ocr_config.yaml
  PIPELINE_ARG="/app/ocr_config.yaml"
  echo "Using generated config: /app/ocr_config.yaml"
fi

# Install HPI GPU + Paddle2ONNX at runtime (libcuda.so.1 available with --gpus all)
# Build-time install fails: ImportError: libcuda.so.1: cannot open shared object file
if ! python3 -m pip show ultra-infer-python >/dev/null 2>&1; then
  echo "Installing HPI GPU plugin (first run only)..."
  PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK=True paddlex --install hpi-gpu 2>/dev/null || true
  PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK=True paddlex --install paddle2onnx 2>/dev/null || true
fi

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
