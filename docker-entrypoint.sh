#!/bin/sh
# Start PaddleX serving in background, then ocr_api proxy
set -e

PADDLEX_PORT=8080

# Performance tuning: auto-detect optimal values if not set
# Detect CPU cores (use nproc if available, else fallback to Python)
if command -v nproc >/dev/null 2>&1; then
  DETECTED_CORES=$(nproc)
else
  DETECTED_CORES=$(python -c "import os; print(os.cpu_count() or 8)")
fi

# Use environment variable if set, otherwise auto-detect optimal value
# Optimal: match CPU cores (or cores - 1 to leave headroom for system)
CPU_THREADS=${PADDLE_CPU_THREADS:-$DETECTED_CORES}
MKLDNN_ENABLED=${FLAGS_use_mkldnn:-1}
# Optimal mkldnn_cache: 20-50, scale with CPU threads (higher for more threads)
# Formula: max(20, min(50, CPU_THREADS * 3))
if [ -z "$PADDLE_MKLDNN_CACHE_CAPACITY" ]; then
  MKLDNN_CACHE=$(python -c "threads = $CPU_THREADS; print(max(20, min(50, threads * 3)))")
else
  MKLDNN_CACHE=$PADDLE_MKLDNN_CACHE_CAPACITY
fi

echo "=== Performance Configuration ==="
echo "Detected CPU cores: $DETECTED_CORES"
echo "CPU Threads: $CPU_THREADS (auto-detected: $DETECTED_CORES)"
echo "MKLDNN Enabled: $MKLDNN_ENABLED"
echo "MKLDNN Cache Capacity: $MKLDNN_CACHE (auto-optimized)"
echo "Det Limit Side Len: ${PADDLE_DET_LIMIT_SIDE_LEN:-768}"
echo "Precision: ${PADDLE_PRECISION:-fp16}"
echo "HPI Backend: ${PADDLE_HPI_BACKEND:-paddle} (paddle|openvino|onnxruntime|auto)"
echo "================================"

# Export for Python processes (update_config.py reads these)
export PADDLE_CPU_THREADS=$CPU_THREADS
export FLAGS_use_mkldnn=$MKLDNN_ENABLED
export PADDLE_MKLDNN_CACHE_CAPACITY=$MKLDNN_CACHE
export PADDLE_DET_LIMIT_SIDE_LEN=${PADDLE_DET_LIMIT_SIDE_LEN:-768}
export PADDLE_PRECISION=${PADDLE_PRECISION:-fp16}
export PADDLE_HPI_BACKEND=${PADDLE_HPI_BACKEND:-paddle}

# Use custom config if present, else default OCR pipeline
if [ -f /app/ocr_config.yaml ]; then
  PIPELINE_ARG="/app/ocr_config.yaml"
  echo "Using custom config: /app/ocr_config.yaml"
  # Update config with current environment variables
  echo "Updating config with performance settings..."
  python update_config.py /app/ocr_config.yaml || echo "Warning: Could not update config file"
  # Verify config (for debugging)
  python verify_config.py /app/ocr_config.yaml || true
else
  PIPELINE_ARG="OCR"
  echo "Using default OCR pipeline"
fi

# Use HPI only when ultra-infer-python is installed (native Linux x86_64)
if pip show ultra-infer-python >/dev/null 2>&1; then
  echo "Using HPI (high-performance backend)"
  HPIP_FLAG="--use_hpip"
  # Create HPI config for performance tuning (cpu_threads, mkldnn_cache_capacity)
  # PaddleX uses ast.literal_eval for --hpi_config, so we output Python literal format (True not true)
  echo "Creating HPI config..."
  python create_hpi_config.py /app/hpi_config.json || echo "Warning: Could not create HPI config"
  if [ -f /app/hpi_config.json ]; then
    HPI_CONFIG_JSON=$(cat /app/hpi_config.json)
    echo "Using HPI config:"
    cat /app/hpi_config.json
  else
    HPI_CONFIG_JSON=""
  fi
else
  echo "Using Paddle Inference backend (HPI not available)"
  HPIP_FLAG=""
  HPI_CONFIG_JSON=""
fi

# Debug: Show the exact command being executed
if [ -n "$HPI_CONFIG_JSON" ]; then
  echo "Executing PaddleX command:"
  echo "  paddlex --serve --pipeline $PIPELINE_ARG --device cpu $HPIP_FLAG --hpi_config \"$HPI_CONFIG_JSON\" --port $PADDLEX_PORT --host 0.0.0.0"
else
  echo "Executing PaddleX command:"
  echo "  paddlex --serve --pipeline $PIPELINE_ARG --device cpu $HPIP_FLAG --port $PADDLEX_PORT --host 0.0.0.0"
fi
echo ""

# Pass --hpi_config with quoted value so it's one argument (Python literal contains spaces)
if [ -n "$HPI_CONFIG_JSON" ]; then
  paddlex --serve --pipeline "$PIPELINE_ARG" --device cpu $HPIP_FLAG --hpi_config "$HPI_CONFIG_JSON" --port "$PADDLEX_PORT" --host 0.0.0.0 &
else
  paddlex --serve --pipeline "$PIPELINE_ARG" --device cpu $HPIP_FLAG --port "$PADDLEX_PORT" --host 0.0.0.0 &
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
exec python ocr_api.py
