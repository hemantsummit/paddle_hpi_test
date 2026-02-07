# OCR API (proxy over PaddleX serving)

Your API format (form-data, URL) → ocr_api proxy → PaddleX serving → OCR results.

## Docker

### Quick Start (Optimized Config)

**Step 1: Build image and generate optimized config**
```bash
./build-optimized.sh
```

**Step 2: Run the container**
```bash
./run-optimized.sh
```

Or customize performance settings:
```bash
# Build with custom settings
PADDLE_CPU_THREADS=8 \
PADDLE_MKLDNN_CACHE_CAPACITY=30 \
FLAGS_use_mkldnn=1 \
./build-optimized.sh

# Run with same settings
PADDLE_CPU_THREADS=8 \
PADDLE_MKLDNN_CACHE_CAPACITY=30 \
FLAGS_use_mkldnn=1 \
./run-optimized.sh
```

**All-in-one script** (build + run):
```bash
./build-and-run-optimized.sh
```

### Optimal performance (native Linux x86_64)

HPI (OpenVINO/ONNX) installs only on native Linux x86_64. For the high-performance backend:

```bash
# On a Linux x86_64 machine (cloud VM, bare metal)
./build-linux.sh
docker run -p 8000:8000 paddleocr-api:latest
```

Or use GitHub Actions: `.github/workflows/build.yml` builds on `ubuntu-latest` (native amd64).

### Any platform (fallback)

```bash
# Build (on Apple Silicon add: --platform linux/amd64)
docker build -t paddleocr-api .

# Run
docker run -p 8000:8000 paddleocr-api
```

Uses Paddle Inference backend when HPI is unavailable. Runs PaddleX serving (internal) + ocr_api proxy (port 8000).

## API (your format)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check |
| POST | `/ocr` | Upload image (form-data `image`) |
| POST | `/ocr/url` | Form field `url` = image URL |

### Example (form-data upload)

```bash
curl -X POST http://localhost:8000/ocr -F "image=@your_image.png"
```

### Example (image URL)

```bash
curl -X POST http://localhost:8000/ocr/url -F "url=https://example.com/image.png"
```

Response:
```json
{
  "success": true,
  "full_text": "...",
  "inference_time_ms": 245.3,
  "image_path": "your_image.png"
}
```

## Local development

1. Start PaddleX serving: `paddlex --serve --pipeline OCR --device cpu --port 8080`
2. Run proxy: `PADDLEX_SERVING_URL=http://localhost:8080 python ocr_api.py`

## Backend behavior

| Build platform | HPI install | Runtime backend |
|----------------|-------------|-----------------|
| Native Linux x86_64 | ✓ | HPI (OpenVINO/ONNX) |
| Apple Silicon / emulated | ✗ | Paddle Inference |

On Apple Silicon, `ultra-infer-python` has no arm64 wheel. Use `build-linux.sh` on a Linux x86_64 VM or GitHub Actions for optimal performance.

## Performance Tuning

See [docs/PERFORMANCE_TUNING.md](docs/PERFORMANCE_TUNING.md) for detailed optimization options.

### Quick Performance Boost

Set environment variables when running the container:

```bash
# Optimized for 8-core CPU
docker run -p 8000:8000 \
  -e PADDLE_CPU_THREADS=8 \
  -e FLAGS_use_mkldnn=1 \
  -e PADDLE_MKLDNN_CACHE_CAPACITY=30 \
  paddleocr-api:latest
```

### Key Configuration Options

- **PADDLE_CPU_THREADS**: Number of CPU threads (default: 10, recommend: number of cores)
- **FLAGS_use_mkldnn**: Enable MKLDNN acceleration (default: 1, Intel CPUs benefit most)
- **PADDLE_MKLDNN_CACHE_CAPACITY**: MKLDNN cache size (default: 20, increase for batch processing)
- **PADDLE_DET_LIMIT_SIDE_LEN**: Detection image side limit (default: 960)
- **PADDLE_PRECISION**: Inference precision (default: fp16 for speed, use fp32 for max accuracy)
- **PADDLE_HPI_BACKEND**: HPI inference backend (default: paddle). Options:
  - `paddle`: Paddle Inference + MKLDNN
  - `openvino`: Intel OpenVINO (often faster on Intel CPUs)
  - `onnxruntime`: ONNX Runtime (cross-platform)
  - `auto`: Let PaddleX choose best backend per model

### Test Performance

```bash
# Test inference time
./performance-test.sh

# Or manually
time curl -X POST http://localhost:8000/ocr -F "image=@test_image.png"
```
