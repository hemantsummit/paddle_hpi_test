#!/usr/bin/env python3
"""
Wrapper for paddlex --serve that sets PaddlePaddle Config before starting.
This ensures performance settings are applied to PaddlePaddle inference.
"""

import os
import sys
import subprocess

def set_paddle_config():
    """Set PaddlePaddle Config via environment before importing PaddlePaddle."""
    
    cpu_threads = int(os.environ.get("PADDLE_CPU_THREADS", "10"))
    mkldnn_cache = int(os.environ.get("PADDLE_MKLDNN_CACHE_CAPACITY", "20"))
    enable_mkldnn = os.environ.get("FLAGS_use_mkldnn", "1") == "1"
    
    # Set environment variables that PaddlePaddle might read
    os.environ["FLAGS_cpu_threads"] = str(cpu_threads)
    os.environ["FLAGS_mkldnn_cache_capacity"] = str(mkldnn_cache)
    os.environ["FLAGS_use_mkldnn"] = "1" if enable_mkldnn else "0"
    
    print(f"Setting PaddlePaddle Config via environment:")
    print(f"  FLAGS_cpu_threads={cpu_threads}")
    print(f"  FLAGS_mkldnn_cache_capacity={mkldnn_cache}")
    print(f"  FLAGS_use_mkldnn={enable_mkldnn}")

if __name__ == "__main__":
    # Set config before importing/starting PaddleX
    set_paddle_config()
    
    # Get the original command arguments
    args = sys.argv[1:]
    
    # Find paddlex command
    paddlex_cmd = ["paddlex"] + args
    
    # Run paddlex with the environment set
    sys.exit(subprocess.call(paddlex_cmd))
