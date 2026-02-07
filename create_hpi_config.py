#!/usr/bin/env python3
"""
Create HPI (High-Performance Inference) config for PaddleX serving.
This config is used with --hpi_config option when --use_hpip is enabled.

PaddleX CLI uses ast.literal_eval() to parse --hpi_config, so we must output
Python literal format (True/False, not JSON true/false).

PADDLE_HPI_BACKEND: "paddle" | "openvino" | "onnxruntime" | "auto"
  - paddle: Paddle Inference + MKLDNN (default)
  - openvino: Intel OpenVINO (often faster on Intel CPUs)
  - onnxruntime: ONNX Runtime (cross-platform)
  - auto: Let PaddleX choose best backend per model
"""

import os
import sys

def create_hpi_config(output_path="/app/hpi_config.json"):
    """Create HPI config as Python literal string from environment variables."""
    
    cpu_threads = int(os.environ.get("PADDLE_CPU_THREADS", "10"))
    mkldnn_cache = int(os.environ.get("PADDLE_MKLDNN_CACHE_CAPACITY", "20"))
    backend = os.environ.get("PADDLE_HPI_BACKEND", "paddle").lower()
    
    # Backend-specific config: Paddle uses cpu_threads/mkldnn_cache_capacity;
    # OpenVINO/ONNX use cpu_num_threads
    if backend == "paddle":
        hpi_config = {
            "backend": "paddle",
            "backend_config": {
                "cpu_threads": cpu_threads,
                "mkldnn_cache_capacity": mkldnn_cache,
            },
        }
    elif backend == "openvino":
        hpi_config = {
            "backend": "openvino",
            "backend_config": {
                "cpu_num_threads": cpu_threads,
            },
        }
    elif backend == "onnxruntime":
        hpi_config = {
            "backend": "onnxruntime",
            "backend_config": {
                "cpu_num_threads": cpu_threads,
            },
        }
    else:
        # "auto" or unknown: let PaddleX choose; pass minimal config.
        # PaddlePredictorOption rejects unknown keys, so we only pass when paddle is used.
        # For auto, use backend_config that works for paddle (most common)
        hpi_config = {
            "backend_config": {
                "cpu_threads": cpu_threads,
                "mkldnn_cache_capacity": mkldnn_cache,
            },
        }
    
    try:
        # PaddleX uses ast.literal_eval() - requires Python format (True not true)
        hpi_config_str = str(hpi_config)
        with open(output_path, 'w') as f:
            f.write(hpi_config_str)
        
        print(f"✓ Created HPI config: {output_path}")
        print(f"  backend: {backend}")
        print(f"  cpu_threads / cpu_num_threads: {cpu_threads}")
        if backend == "paddle" or backend not in ("openvino", "onnxruntime"):
            print(f"  mkldnn_cache_capacity: {mkldnn_cache}")
        return True
    except Exception as e:
        print(f"Error creating HPI config: {e}", file=sys.stderr)
        return False

if __name__ == "__main__":
    output_path = sys.argv[1] if len(sys.argv) > 1 else "/app/hpi_config.json"
    success = create_hpi_config(output_path)
    sys.exit(0 if success else 1)
