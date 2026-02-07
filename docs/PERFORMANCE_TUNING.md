# Performance Tuning Guide for PaddleOCR/PaddleX

This guide covers configuration options to optimize OCR inference performance.

## Current Configuration Analysis

From your logs, the current settings are:
- **cpu_threads**: 10
- **mkldnn_cache_capacity**: 10
- **run_mode**: mkldnn
- **device_type**: cpu
- **Models**: PP-OCRv5_server_* (server models for maximum accuracy)

## Performance Tuning Options

### 1. CPU Threads (`cpu_threads`)

**Current**: 10  
**Recommendation**: Set to number of CPU cores (or cores - 1 to leave headroom)

```bash
# Check CPU cores
nproc  # or: lscpu | grep "^CPU(s):"

# Set via environment variable
export PADDLE_CPU_THREADS=8  # Adjust based on your CPU
```

**Impact**: More threads = better parallelism, but diminishing returns after ~2x physical cores. Too many threads can cause context switching overhead.

### 2. MKLDNN Cache Capacity (`mkldnn_cache_capacity`)

**Current**: 10  
**Recommendation**: Increase to 20-50 for better caching of intermediate results

**Impact**: Reduces repeated computation overhead, especially for batch processing or similar image sizes.

### 3. Enable MKLDNN (`FLAGS_use_mkldnn`)

**Current**: Disabled in Dockerfile (`FLAGS_use_mkldnn=0`), but logs show mkldnn is being used  
**Recommendation**: Enable explicitly for Intel CPUs

```bash
export FLAGS_use_mkldnn=1
```

**Impact**: Significant speedup on Intel CPUs (2-5x faster). Note: Your Dockerfile currently disables this, but PaddleX may override it.

### 4. Model Precision (`precision`)

**Options**: `fp32` (default), `fp16`, `int8`

**Recommendation**: 
- **fp16**: ~2x faster, minimal accuracy loss (if CPU supports it)
- **int8**: ~4x faster, some accuracy loss (requires quantization)

**Impact**: Lower precision = faster inference, but may reduce accuracy slightly.

### 5. IR Optimization (`ir_optim`)

**Current**: Enabled by default  
**Recommendation**: Keep enabled

**Impact**: Graph optimizations can provide 10-30% speedup.

### 6. Batch Processing

**Current**: Single image processing  
**Recommendation**: Process multiple images in batch if possible

**Impact**: Better CPU utilization, especially with higher thread counts.

### 7. Image Preprocessing

**Current**: All preprocessing enabled for maximum accuracy
- `use_doc_orientation_classify=True` – document rotation correction
- `use_doc_unwarping=True` – curved document straightening
- `use_textline_orientation=True` – sideways text handling

### 8. Memory Optimization

**Options**:
- Reduce image size before processing (resize large images)
- Use image compression
- Limit concurrent requests

### 9. High-Performance Inference (HPI)

**Current**: Using Paddle Inference backend  
**Recommendation**: Use HPI when available (requires native Linux x86_64)

HPI provides:
- OpenVINO backend (Intel CPUs)
- ONNX Runtime backend
- Automatic backend selection
- Better performance (often 2-3x faster)

**To enable**: Build on native Linux x86_64 (see `build-linux.sh`)

## Configuration Methods

### Method 1: Environment Variables (Recommended)

Set these before starting the container:

```bash
docker run -p 8000:8000 \
  -e PADDLE_CPU_THREADS=8 \
  -e FLAGS_use_mkldnn=1 \
  -e PADDLE_MKLDNN_CACHE_CAPACITY=20 \
  paddleocr-api:latest
```

### Method 2: Custom YAML Config

Create a custom `ocr_config.yaml` with optimized settings:

```yaml
Global:
  use_gpu: false
  cpu_threads: 8
  enable_mkldnn: true
  mkldnn_cache_capacity: 20
  precision: fp32
  ir_optim: true
```

### Method 3: Modify Dockerfile

Update the Dockerfile to set default values (see updated Dockerfile).

## Quick Performance Test

Test different configurations:

```bash
# Baseline
docker run -p 8000:8000 paddleocr-api:latest

# Optimized (adjust values)
docker run -p 8000:8000 \
  -e PADDLE_CPU_THREADS=$(nproc) \
  -e FLAGS_use_mkldnn=1 \
  -e PADDLE_MKLDNN_CACHE_CAPACITY=30 \
  paddleocr-api:latest

# Test with curl
time curl -X POST http://localhost:8000/ocr -F "image=@test_image.png"
```

## Expected Performance Improvements

| Configuration | Expected Speedup | Notes |
|--------------|------------------|-------|
| Enable MKLDNN | 2-5x | Intel CPUs only |
| Increase cpu_threads | 1.5-2x | Up to ~2x cores |
| Increase cache capacity | 1.1-1.3x | Batch processing |
| Use fp16 precision | 1.5-2x | If supported |
| Enable HPI | 2-3x | Requires native Linux x86_64 |

## Troubleshooting

### MKLDNN Not Working
- Check CPU: `lscpu | grep -i "model name"` (Intel CPUs work best)
- Verify: `export FLAGS_use_mkldnn=1` is set
- Check logs for MKLDNN warnings

### High CPU Usage
- Reduce `cpu_threads` if system becomes unresponsive
- Limit concurrent requests
- Use request queuing

### Memory Issues
- Reduce `mkldnn_cache_capacity`
- Process images in smaller batches

## Monitoring

Monitor performance metrics:
- Inference time (returned in API response)
- CPU usage: `docker stats <container_id>`
- Memory usage: `docker stats <container_id>`
- Throughput: requests per second
