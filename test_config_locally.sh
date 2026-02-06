#!/bin/bash
# Test script to verify config updates work locally
# This helps debug the configuration before pushing

set -e

echo "=== Testing Config Updates Locally ==="
echo ""

# Test 1: Check if update_config.py can read and update a sample config
echo "Test 1: Testing update_config.py with sample config..."
cat > /tmp/test_config.yaml << 'EOF'
SubModules:
  det:
    model_dir: test
  rec:
    model_dir: test
pipeline_name: OCR
EOF

export PADDLE_CPU_THREADS=4
export PADDLE_MKLDNN_CACHE_CAPACITY=30
export FLAGS_use_mkldnn=1

python3 update_config.py /tmp/test_config.yaml

echo ""
echo "Updated config:"
cat /tmp/test_config.yaml
echo ""

# Test 2: Check if create_hpi_config.py creates correct JSON
echo "Test 2: Testing create_hpi_config.py..."
python3 create_hpi_config.py /tmp/test_hpi_config.json

echo ""
echo "HPI config created:"
cat /tmp/test_hpi_config.json
echo ""

# Test 3: Verify the config structure matches what PaddleX expects
echo "Test 3: Checking config structure..."
python3 -c "
import yaml
with open('/tmp/test_config.yaml', 'r') as f:
    config = yaml.safe_load(f)
    
print('Config keys:', list(config.keys()))
if 'SubModules' in config:
    for module_name, module_config in config['SubModules'].items():
        print(f'  {module_name}:', list(module_config.keys()) if isinstance(module_config, dict) else 'not a dict')
        if isinstance(module_config, dict):
            print(f'    cpu_threads: {module_config.get(\"cpu_threads\", \"NOT SET\")}')
            print(f'    mkldnn_cache_capacity: {module_config.get(\"mkldnn_cache_capacity\", \"NOT SET\")}')
"

echo ""
echo "=== Tests Complete ==="
echo "If all tests pass, the config update logic should work in the container."
