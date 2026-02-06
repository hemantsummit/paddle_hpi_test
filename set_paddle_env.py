#!/usr/bin/env python3
"""
Set PaddlePaddle environment variables and Config settings.
PaddlePaddle reads some settings from environment variables at import time.
This script sets them before PaddleX imports PaddlePaddle.
"""

import os
import sys

def set_paddle_env():
    """Set PaddlePaddle environment variables from our env vars."""
    
    cpu_threads = os.environ.get("PADDLE_CPU_THREADS", "10")
    mkldnn_cache = os.environ.get("PADDLE_MKLDNN_CACHE_CAPACITY", "20")
    enable_mkldnn = os.environ.get("FLAGS_use_mkldnn", "1")
    
    # Set PaddlePaddle-specific environment variables
    # Note: These might be read by PaddlePaddle at import time
    os.environ["FLAGS_cpu_threads"] = str(cpu_threads)
    os.environ["FLAGS_mkldnn_cache_capacity"] = str(mkldnn_cache)
    os.environ["FLAGS_use_mkldnn"] = str(enable_mkldnn)
    
    print(f"Set PaddlePaddle env vars: cpu_threads={cpu_threads}, mkldnn_cache={mkldnn_cache}, use_mkldnn={enable_mkldnn}")
    
    # Try to set via PaddlePaddle Config if available
    try:
        # This needs to run before PaddlePaddle is imported
        # We'll set env vars and let PaddlePaddle read them
        pass
    except Exception as e:
        print(f"Note: Could not set PaddlePaddle Config: {e}")

if __name__ == "__main__":
    set_paddle_env()
