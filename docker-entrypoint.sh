#!/bin/sh
# Start PaddleX serving in background, then ocr_api proxy
set -e

PADDLEX_PORT=8080

# Performance tuning: read from environment variables with defaults
CPU_THREADS=${PADDLE_CPU_THREADS:-10}
MKLDNN_ENABLED=${FLAGS_use_mkldnn:-1}
MKLDNN_CACHE=${PADDLE_MKLDNN_CACHE_CAPACITY:-20}

echo "=== Performance Configuration ==="
echo "CPU Threads: $CPU_THREADS"
echo "MKLDNN Enabled: $MKLDNN_ENABLED"
echo "MKLDNN Cache Capacity: $MKLDNN_CACHE"
echo "================================"

# Export for Python processes
export PADDLE_CPU_THREADS=$CPU_THREADS
export FLAGS_use_mkldnn=$MKLDNN_ENABLED
export PADDLE_MKLDNN_CACHE_CAPACITY=$MKLDNN_CACHE

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
HPI_CONFIG_ARG=""
if pip show ultra-infer-python >/dev/null 2>&1; then
  echo "Using HPI (high-performance backend)"
  HPIP_FLAG="--use_hpip"
  
  # Create HPI config file with performance settings
  echo "Creating HPI config..."
  python create_hpi_config.py /app/hpi_config.json || echo "Warning: Could not create HPI config"
  
  # Use HPI config if it was created
  # Note: --hpi_config might expect JSON string or file path - try file path first
  # If that fails, we'll need to pass JSON content directly
  if [ -f /app/hpi_config.json ]; then
    echo "Using HPI config: /app/hpi_config.json"
    echo "HPI config contents:"
    cat /app/hpi_config.json
    echo ""
    # Try passing as file path first (some versions might accept this)
    # If this causes errors, we'll need to read and pass JSON content
    HPI_CONFIG_ARG="--hpi_config /app/hpi_config.json"
  else
    echo "Warning: HPI config file not found after creation"
  fi
else
  echo "Using Paddle Inference backend (HPI not available)"
  HPIP_FLAG=""
fi

# Debug: Show the exact command being executed
echo "Executing PaddleX command:"
if [ -n "$HPI_CONFIG_ARG" ]; then
  echo "  Using Python wrapper to handle HPI config format"
  echo "  paddlex --serve --pipeline $PIPELINE_ARG --device cpu $HPIP_FLAG $HPI_CONFIG_ARG --port $PADDLEX_PORT --host 0.0.0.0"
  # Use Python wrapper to properly format HPI config (PaddleX expects JSON string, not file path)
  python paddlex_serve_wrapper.py --serve --pipeline "$PIPELINE_ARG" --device cpu $HPIP_FLAG $HPI_CONFIG_ARG --port "$PADDLEX_PORT" --host 0.0.0.0 &
else
  echo "  paddlex --serve --pipeline $PIPELINE_ARG --device cpu $HPIP_FLAG --port $PADDLEX_PORT --host 0.0.0.0"
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
