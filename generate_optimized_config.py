#!/usr/bin/env python3
"""
Generate optimized OCR config YAML for PaddleX serving.

Usage:
    python generate_optimized_config.py [--cpu-threads N] [--mkldnn-cache N] [--enable-mkldnn] [--output config.yaml]
"""

import argparse
import os
import sys
from paddleocr import PaddleOCR


def generate_config(
    cpu_threads: int = None,
    mkldnn_cache: int = None,
    enable_mkldnn: bool = None,
    output_path: str = "/app/ocr_config.yaml",
):
    """Generate optimized OCR config YAML."""
    
    # Get values from environment or use defaults
    cpu_threads = cpu_threads or int(os.environ.get("PADDLE_CPU_THREADS", "10"))
    mkldnn_cache = mkldnn_cache or int(os.environ.get("PADDLE_MKLDNN_CACHE_CAPACITY", "20"))
    enable_mkldnn = enable_mkldnn if enable_mkldnn is not None else os.environ.get("FLAGS_use_mkldnn", "1") == "1"
    
    print(f"Generating OCR config:")
    print(f"  CPU Threads: {cpu_threads}")
    print(f"  MKLDNN Enabled: {enable_mkldnn}")
    print(f"  MKLDNN Cache Capacity: {mkldnn_cache}")
    print(f"  Output: {output_path}")
    
    # Create PaddleOCR instance with optimized settings
    ocr = PaddleOCR(
        use_doc_orientation_classify=False,
        use_doc_unwarping=False,
        use_textline_orientation=False,
        cpu_threads=cpu_threads,
        enable_mkldnn=enable_mkldnn,
        # Note: mkldnn_cache_capacity may need to be set via Config
        # PaddleOCR API may not expose all options directly
    )
    
    # Export config
    ocr.export_paddlex_config_to_yaml(output_path)
    
    print(f"✓ Config generated: {output_path}")
    print("\nTo use this config, ensure it's copied to /app/ocr_config.yaml in the container")
    
    # Try to update mkldnn_cache_capacity in the YAML if possible
    try:
        import yaml
        with open(output_path, 'r') as f:
            config = yaml.safe_load(f)
        
        # Update cache capacity if config structure supports it
        if 'Global' in config:
            config['Global']['mkldnn_cache_capacity'] = mkldnn_cache
        elif isinstance(config, dict):
            # Try to find where to set it
            for key in config:
                if isinstance(config[key], dict) and 'mkldnn' in str(config[key]).lower():
                    config[key]['mkldnn_cache_capacity'] = mkldnn_cache
        
        with open(output_path, 'w') as f:
            yaml.dump(config, f, default_flow_style=False)
        print(f"✓ Updated mkldnn_cache_capacity to {mkldnn_cache}")
    except ImportError:
        print("Note: Install PyYAML to auto-update mkldnn_cache_capacity in YAML")
    except Exception as e:
        print(f"Note: Could not update mkldnn_cache_capacity automatically: {e}")
        print(f"  Set PADDLE_MKLDNN_CACHE_CAPACITY={mkldnn_cache} environment variable instead")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate optimized OCR config")
    parser.add_argument("--cpu-threads", type=int, help="Number of CPU threads (default: 10)")
    parser.add_argument("--mkldnn-cache", type=int, help="MKLDNN cache capacity (default: 20)")
    parser.add_argument("--enable-mkldnn", action="store_true", help="Enable MKLDNN (default: True)")
    parser.add_argument("--disable-mkldnn", action="store_true", help="Disable MKLDNN")
    parser.add_argument("--output", default="/app/ocr_config.yaml", help="Output config path")
    
    args = parser.parse_args()
    
    enable_mkldnn = None
    if args.enable_mkldnn:
        enable_mkldnn = True
    elif args.disable_mkldnn:
        enable_mkldnn = False
    
    generate_config(
        cpu_threads=args.cpu_threads,
        mkldnn_cache=args.mkldnn_cache,
        enable_mkldnn=enable_mkldnn,
        output_path=args.output,
    )
