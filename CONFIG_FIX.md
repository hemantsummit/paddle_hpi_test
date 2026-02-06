# Config Fix for Performance Settings

## Problem

The logs show that PaddleX serving is using default values instead of the optimized settings:
- Expected: `cpu_threads: 4`, `mkldnn_cache_capacity: 30`
- Actual: `cpu_threads: 10`, `mkldnn_cache_capacity: 10`

## Root Cause

PaddleX serving reads the YAML config file, but:
1. The config file might not have the correct structure
2. PaddleX may not read all performance settings from the YAML
3. Some settings might need to be set via environment variables or PaddlePaddle Config API

## Solution

Added three scripts to ensure settings are applied:

1. **`update_config.py`** - Updates the YAML config file at runtime with environment variables
2. **`verify_config.py`** - Verifies the config file structure and values (for debugging)
3. **Updated `docker-entrypoint.sh`** - Runs update_config.py before starting PaddleX

## How It Works

1. **Build time**: `generate_optimized_config.py` creates the initial config with performance settings
2. **Runtime**: `update_config.py` updates the config file with current environment variables before PaddleX starts
3. **Verification**: `verify_config.py` shows what values are actually in the config (for debugging)

## Testing

After rebuilding and running, check the logs:

```bash
# Rebuild
./build-optimized.sh

# Run
./run-optimized.sh

# Check logs
docker logs paddleocr-api | grep -A 5 "Performance Configuration"
docker logs paddleocr-api | grep "cpu_threads"
```

You should see:
- The config being updated
- The verified config values matching your environment variables
- PaddleX using the correct values (check the "Paddle predictor option" lines)

## If Still Not Working

If PaddleX still uses defaults, it might be that:
1. PaddleX doesn't read these settings from YAML (may need PaddlePaddle Config API)
2. The YAML structure is different than expected
3. Settings need to be set via different environment variables

In that case, check the actual YAML structure:
```bash
docker exec paddleocr-api cat /app/ocr_config.yaml
```

And verify what PaddleX is actually reading by checking the full logs.
