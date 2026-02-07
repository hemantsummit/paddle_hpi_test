#!/bin/bash
# Test PaddleX --hpi_config with Python literal format (for ast.literal_eval)
# Run: conda activate ray && ./test_hpi_local.sh

set -e
cd "$(dirname "$0")"

echo "=== Testing create_hpi_config.py output format ==="
export PADDLE_CPU_THREADS=4
export PADDLE_MKLDNN_CACHE_CAPACITY=30
export FLAGS_use_mkldnn=1

python create_hpi_config.py /tmp/hpi_config.json
echo ""
echo "Config content:"
cat /tmp/hpi_config.json
echo ""

echo "=== Verifying ast.literal_eval accepts it ==="
python -c "
import ast
with open('/tmp/hpi_config.json') as f:
    s = f.read()
result = ast.literal_eval(s)
print('parsed OK:', result)
"
echo ""

echo "=== Testing paddlex --help (quick sanity check) ==="
conda run -n ray paddlex --help 2>&1 | grep -A1 "hpi_config" || true
echo ""

echo "=== Testing paddlex with --hpi_config (dry run - will fail if pipeline not found, but arg parsing should succeed) ==="
HPI_CONFIG=$(cat /tmp/hpi_config.json)
# Use OCR pipeline (default) - may fail later but --hpi_config parsing should work
conda run -n ray paddlex --serve --pipeline OCR --device cpu --use_hpip --hpi_config "$HPI_CONFIG" --port 8080 --host 0.0.0.0 2>&1 | head -30 || true

echo ""
echo "If no 'invalid literal_eval' error above, the fix works!"
