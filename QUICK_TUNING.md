# Quick Performance Tuning Reference

## Current Settings (from your logs)
```
cpu_threads: 10
mkldnn_cache_capacity: 10
run_mode: mkldnn
device_type: cpu
```

## Recommended Changes

### 1. Increase CPU Threads
**Current**: 10  
**Recommended**: Match your CPU cores (check with `nproc`)

```bash
docker run -p 8000:8000 \
  -e PADDLE_CPU_THREADS=$(nproc) \
  paddleocr-api:latest
```

### 2. Increase MKLDNN Cache Capacity
**Current**: 10  
**Recommended**: 20-50 (higher for batch processing)

```bash
docker run -p 8000:8000 \
  -e PADDLE_MKLDNN_CACHE_CAPACITY=30 \
  paddleocr-api:latest
```

### 3. Ensure MKLDNN is Enabled
**Current**: Enabled (but Dockerfile had it disabled)  
**Status**: Now enabled by default in updated Dockerfile

```bash
docker run -p 8000:8000 \
  -e FLAGS_use_mkldnn=1 \
  paddleocr-api:latest
```

### 4. Combined Optimized Configuration

```bash
# For an 8-core CPU
docker run -p 8000:8000 \
  -e PADDLE_CPU_THREADS=8 \
  -e FLAGS_use_mkldnn=1 \
  -e PADDLE_MKLDNN_CACHE_CAPACITY=30 \
  paddleocr-api:latest
```

## Expected Improvements

| Change | Expected Speedup | Risk |
|--------|-----------------|------|
| Increase cpu_threads to match cores | 1.5-2x | Low |
| Increase mkldnn_cache_capacity to 30 | 1.1-1.3x | Low |
| Enable MKLDNN (if disabled) | 2-5x | Low (Intel CPUs) |

## Testing

After making changes, test performance:

```bash
# Single request
time curl -X POST http://localhost:8000/ocr -F "image=@test.png"

# Multiple requests (average)
./performance-test.sh
```

## Other Options to Explore

1. **Use Mobile Models**: Faster but less accurate
   - Modify Dockerfile to use mobile models instead of server models

2. **Enable HPI**: 2-3x faster (requires native Linux x86_64)
   - Build on Linux x86_64: `./build-linux.sh`

3. **Reduce Image Size**: Preprocess images to smaller dimensions
   - Add image resizing before OCR

4. **Batch Processing**: Process multiple images together
   - Modify API to accept multiple images

See [PERFORMANCE_TUNING.md](PERFORMANCE_TUNING.md) for detailed options.
