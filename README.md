# OCR API (proxy over PaddleX serving)

Your API format (form-data, URL) → ocr_api proxy → PaddleX serving → OCR results.

## Docker

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
