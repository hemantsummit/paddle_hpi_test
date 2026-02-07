#!/usr/bin/env python3
"""
Create HPI (High-Performance Inference) config file for PaddleX serving.
This config is used with --hpi_config option when --use_hpip is enabled.
"""

import os
import json
import sys

def create_hpi_config(output_path="/app/hpi_config.json"):
    """Create HPI config JSON file from environment variables."""
    
    cpu_threads = int(os.environ.get("PADDLE_CPU_THREADS", "10"))
    mkldnn_cache = int(os.environ.get("PADDLE_MKLDNN_CACHE_CAPACITY", "20"))
    enable_mkldnn = os.environ.get("FLAGS_use_mkldnn", "1") == "1"
    
    # HPI config structure per PaddleX High-Performance Inference docs:
    # backend_config overrides defaults; for "paddle" backend, use PaddlePredictorOption attributes
    hpi_config = {
        "backend": "paddle",
        "backend_config": {
            "cpu_threads": cpu_threads,
            "mkldnn_cache_capacity": mkldnn_cache,
            "enable_mkldnn": enable_mkldnn,
        },
    }
    
    try:
        with open(output_path, 'w') as f:
            # Compact JSON (no spaces) for safe shell pass-through to --hpi_config
            json.dump(hpi_config, f, separators=(',', ':'))
        
        print(f"✓ Created HPI config: {output_path}")
        print(f"  cpu_threads: {cpu_threads}")
        print(f"  mkldnn_cache_capacity: {mkldnn_cache}")
        print(f"  enable_mkldnn: {enable_mkldnn}")
        return True
    except Exception as e:
        print(f"Error creating HPI config: {e}", file=sys.stderr)
        return False

if __name__ == "__main__":
    output_path = sys.argv[1] if len(sys.argv) > 1 else "/app/hpi_config.json"
    success = create_hpi_config(output_path)
    sys.exit(0 if success else 1)
