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

## Current Issue

**Problem**: PaddleX is still using `cpu_threads: 10` and `mkldnn_cache_capacity: 10` even though:
- Environment variables are set correctly (4 and 30)
- Config file is being updated
- Config verification shows correct values

**Root Cause**: PaddleX serving creates PaddlePaddle Config objects internally and doesn't read `cpu_threads` and `mkldnn_cache_capacity` from the YAML config file. These are PaddlePaddle inference engine settings that need to be set via the Config API, not the YAML.

**Evidence**: The log shows "The Paddle Inference backend is selected with the default configuration" - this means PaddleX is using its own defaults, not reading from YAML.

## Potential Solutions

### Option 1: Modify PaddleX Source (Not Recommended)
Modify PaddleX's internal code to read these settings from the config or environment.

### Option 2: Use PaddlePaddle Config API (Needs Investigation)
Set these via PaddlePaddle's Config API before PaddleX creates its Config objects. This would require:
- Intercepting PaddleX's Config creation
- Setting cpu_threads and mkldnn_cache_capacity via Config.set_cpu_math_library_num_threads() or similar
- This is complex and may not be possible without modifying PaddleX

### Option 3: Accept Limitations (Current State)
The YAML config might not support these low-level PaddlePaddle inference settings. The settings might need to be:
- Set at PaddlePaddle build time
- Configured via PaddlePaddle's C++ API (not accessible from Python)
- Or these settings might not be configurable via PaddleX serving

### Option 4: Check PaddleX Documentation
Verify if PaddleX serving supports these settings via:
- Command-line arguments
- Different YAML structure
- PaddleX-specific environment variables

## Next Steps

1. Check PaddleX serving documentation for performance tuning options
2. Inspect the actual YAML structure: `docker exec paddleocr-api cat /app/ocr_config.yaml`
3. Check if PaddleX has command-line options for these settings
4. Consider if these settings are actually used by PaddleX (they might be ignored)

## Solution: Use --hpi_config Option

Based on [PaddleX serving documentation](https://paddlepaddle.github.io/PaddleX/3.3/en/pipeline_deploy/serving.html), when using `--use_hpip` (high-performance inference plugin), we should use the `--hpi_config` option to pass performance settings.

**New approach:**
1. Create `hpi_config.json` with `cpu_threads` and `mkldnn_cache_capacity`
2. Pass it via `--hpi_config /app/hpi_config.json` when starting PaddleX serving
3. This ensures HPI plugin reads the performance settings correctly

**Implementation:**
- Added `create_hpi_config.py` to generate HPI config JSON from environment variables
- Updated `docker-entrypoint.sh` to create and use HPI config when `--use_hpip` is enabled
- The HPI config is created at runtime with current environment variable values

## Note

The YAML config file is still being updated for compatibility, but the primary method for performance tuning when using HPI is via `--hpi_config`. The performance might also be optimized via:
- MKLDNN being enabled (which is working)
- HPI config settings (cpu_threads, mkldnn_cache_capacity)
- Other YAML settings that PaddleX does read
