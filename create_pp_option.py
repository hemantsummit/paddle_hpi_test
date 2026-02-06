#!/usr/bin/env python3
"""
Create PaddlePaddle option string for --pp_option argument.
Format: "{'cpu_threads': N, 'mkldnn_cache_capacity': M}"
"""

import os
import sys

def create_pp_option():
    """Create PaddlePaddle option string from environment variables."""
    
    cpu_threads = int(os.environ.get("PADDLE_CPU_THREADS", "10"))
    mkldnn_cache = int(os.environ.get("PADDLE_MKLDNN_CACHE_CAPACITY", "20"))
    
    # Format as Python dict string (not JSON - PaddleX uses ast.literal_eval)
    # Single quotes for Python dict format
    pp_option = f"{{'cpu_threads': {cpu_threads}, 'mkldnn_cache_capacity': {mkldnn_cache}}}"
    
    print(f"PaddlePaddle option string: {pp_option}")
    return pp_option

if __name__ == "__main__":
    option_str = create_pp_option()
    print(option_str)
