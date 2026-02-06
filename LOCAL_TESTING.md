# Local Testing Guide

## Quick Test

```bash
# Build and run (automatically detects ARM64 and uses --platform linux/amd64)
./build-and-run-optimized.sh

# Or with custom settings
PADDLE_CPU_THREADS=4 \
PADDLE_MKLDNN_CACHE_CAPACITY=30 \
./build-and-run-optimized.sh
```

## What to Check in Logs

After running, check the logs:

```bash
docker logs paddleocr-api | grep -A 20 "Performance Configuration"
```

### Expected Output

You should see:

1. **Performance Configuration**:
   ```
   === Performance Configuration ===
   CPU Threads: 4
   MKLDNN Enabled: 1
   MKLDNN Cache Capacity: 30
   ```

2. **Config Update**:
   ```
   Updating config with performance settings...
   ✓ Updated config: cpu_threads=4, mkldnn_cache=30, enable_mkldnn=True
   ```

3. **HPI Config** (if HPI is available):
   ```
   Creating HPI config...
   ✓ Created HPI config: /app/hpi_config.json
   Using HPI config: /app/hpi_config.json
   HPI config contents:
   {
     "cpu_threads": 4,
     "mkldnn_cache_capacity": 30,
     ...
   }
   ```

4. **PaddleX Command**:
   ```
   Executing PaddleX command:
     paddlex --serve --pipeline /app/ocr_config.yaml --device cpu --use_hpip --hpi_config /app/hpi_config.json --port 8080 --host 0.0.0.0
   ```

5. **Actual Paddle Predictor Options** (the key check):
   ```
   Paddle predictor option: ..., cpu_threads: 4, ..., mkldnn_cache_capacity: 30
   ```
   
   **If you still see `cpu_threads: 10` and `mkldnn_cache_capacity: 10` here**, then PaddleX is not reading our configs.

## Troubleshooting

### If values are still 10:

1. **Check if HPI config is being created**:
   ```bash
   docker exec paddleocr-api cat /app/hpi_config.json
   ```

2. **Check if YAML config has inference_config sections**:
   ```bash
   docker exec paddleocr-api python verify_config.py /app/ocr_config.yaml
   ```

3. **Check the actual YAML structure**:
   ```bash
   docker exec paddleocr-api cat /app/ocr_config.yaml | grep -A 10 "inference_config"
   ```

### Possible Issues

1. **HPI config format might be wrong** - PaddleX might expect a different JSON structure
2. **YAML inference_config might not be read** - PaddleX might create Config objects with defaults
3. **Settings might need to be set via PaddlePaddle Config API** - Not via YAML/HPI config

## Next Steps Based on Results

- **If HPI config is created but not used**: Check PaddleX documentation for correct HPI config format
- **If YAML config is updated but not read**: PaddleX might not support these settings via YAML
- **If both are correct but values are still 10**: This might be a PaddleX limitation - settings might need to be set via PaddlePaddle's Config API at runtime

## Testing Config Scripts Locally

```bash
# Install pyyaml first
pip install pyyaml

# Then test
./test_config_locally.sh
```

This will verify that the config update scripts work correctly before testing in Docker.
