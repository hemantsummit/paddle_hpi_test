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

# Performance tuning: support build-time overrides via --build-arg
# These can be overridden at build time: docker build --build-arg PADDLE_CPU_THREADS=8 ...
ARG PADDLE_CPU_THREADS=10
ARG FLAGS_use_mkldnn=1
ARG PADDLE_MKLDNN_CACHE_CAPACITY=20

# Set as ENV so they're available to the RUN command below and at runtime
# Note: FLAGS_use_mkldnn=0 was set to avoid Paddle 3.3+ bug, but PaddleX may override
# Enable MKLDNN for better performance on Intel CPUs (test if stable)
ENV FLAGS_use_mkldnn=${FLAGS_use_mkldnn}
ENV PADDLE_CPU_THREADS=${PADDLE_CPU_THREADS}
ENV PADDLE_MKLDNN_CACHE_CAPACITY=${PADDLE_MKLDNN_CACHE_CAPACITY}

# OCR config: disable doc orientation/unwarping/textline_ori (keep server models)
# Performance tuning: reads from ENV variables set above (can be overridden at build/runtime)
RUN python -c "\
from paddleocr import PaddleOCR; \
import os; \
cpu_threads = int(os.environ.get('PADDLE_CPU_THREADS', '10')); \
enable_mkldnn = os.environ.get('FLAGS_use_mkldnn', '1') == '1'; \
p = PaddleOCR( \
    use_doc_orientation_classify=False, \
    use_doc_unwarping=False, \
    use_textline_orientation=False, \
    cpu_threads=cpu_threads, \
    enable_mkldnn=enable_mkldnn, \
); \
p.export_paddlex_config_to_yaml('/app/ocr_config.yaml')"

COPY ocr_api.py .
COPY generate_optimized_config.py .
COPY update_config.py .
COPY verify_config.py .
COPY docker-entrypoint.sh /app/
RUN chmod +x /app/docker-entrypoint.sh

EXPOSE 8000

# PaddleX (8080) + ocr_api proxy (8000). Your API: POST /ocr (form-data), POST /ocr/url
CMD ["/app/docker-entrypoint.sh"]
