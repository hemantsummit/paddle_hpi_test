# GPU Setup (g4dn.xlarge / Tesla T4)

Separate GPU build that uses PaddleX [High-Performance Inference](https://paddlepaddle.github.io/PaddleX/3.3/en/pipeline_deploy/high_performance_inference.html) with defaults. No config generation—uses built-in OCR pipeline.

## Prerequisites (Amazon Linux)

1. **NVIDIA Container Toolkit** (for `docker run --gpus`):

```bash
# Amazon Linux 2
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.repo | sudo tee /etc/yum.repos.d/nvidia-container-toolkit.repo
sudo yum install -y nvidia-container-toolkit
sudo systemctl restart docker
```

2. **Verify GPU**:
```bash
nvidia-smi
```

## Build & Run

```bash
./build-gpu.sh
./run-gpu.sh
```

Or manually:
```bash
docker build -f Dockerfile.gpu -t paddleocr-api-gpu .
docker run --gpus all -p 8000:8000 paddleocr-api-gpu
```

## Test

```bash
curl -X POST http://localhost:8000/ocr -F "image=@your_image.png"
```

## Notes

- **CUDA 11.8**: Image uses `paddlepaddle-gpu` with CUDA 11.8. Tesla T4 and driver 590.x are compatible.
- **HPI**: When `ultra-infer-python` is available, enables HPI (TensorRT/ONNX Runtime backends).
- **First run**: May take longer while models are downloaded and compiled.
