FROM python:3.11-slim

WORKDIR /app

# PaddlePaddle + OpenCV system deps; curl for startup health check
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 \
    libgl1 \
    libglib2.0-0 \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# HPI deps (Linux x86_64 only). Succeeds on native linux/amd64; fails on arm64/emulated.
# For optimal performance: build on native Linux x86_64 (see build-linux.sh, .github/workflows/build.yml)
ENV PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK=True
RUN paddleocr install_hpi_deps cpu || true

# PaddleX serving plugin
RUN paddlex --install serving

# OCR config: disable doc orientation/unwarping/textline_ori (keep server models)
RUN python -c "\
from paddleocr import PaddleOCR; \
p = PaddleOCR( \
    use_doc_orientation_classify=False, \
    use_doc_unwarping=False, \
    use_textline_orientation=False, \
); \
p.export_paddlex_config_to_yaml('/app/ocr_config.yaml')"

# Disable OneDNN to avoid ConvertPirAttribute2RuntimeAttribute bug (Paddle 3.3+)
ENV FLAGS_use_mkldnn=0

COPY ocr_api.py .
COPY docker-entrypoint.sh /app/
RUN chmod +x /app/docker-entrypoint.sh

EXPOSE 8000

# PaddleX (8080) + ocr_api proxy (8000). Your API: POST /ocr (form-data), POST /ocr/url
CMD ["/app/docker-entrypoint.sh"]
