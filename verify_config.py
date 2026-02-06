#!/usr/bin/env python3
"""
Verify OCR config YAML structure and values.
"""

import os
import sys
import yaml

def verify_config(config_path="/app/ocr_config.yaml"):
    """Verify config file structure and print current values."""
    
    if not os.path.exists(config_path):
        print(f"Config file not found: {config_path}")
        return False
    
    try:
        with open(config_path, 'r') as f:
            config = yaml.safe_load(f)
        
        print(f"\n=== Config File: {config_path} ===")
        print(f"Config structure: {list(config.keys())}")
        
        # Check Global section
        if 'Global' in config:
            print("\nGlobal section:")
            global_section = config['Global']
            print(f"  cpu_threads: {global_section.get('cpu_threads', 'NOT SET')}")
            print(f"  enable_mkldnn: {global_section.get('enable_mkldnn', 'NOT SET')}")
            print(f"  mkldnn_cache_capacity: {global_section.get('mkldnn_cache_capacity', 'NOT SET')}")
        
        # Check Det section
        if 'Det' in config:
            print("\nDet section:")
            det_section = config['Det'] if isinstance(config['Det'], dict) else {}
            print(f"  cpu_threads: {det_section.get('cpu_threads', 'NOT SET')}")
            print(f"  enable_mkldnn: {det_section.get('enable_mkldnn', 'NOT SET')}")
            print(f"  mkldnn_cache_capacity: {det_section.get('mkldnn_cache_capacity', 'NOT SET')}")
        
        # Check Rec section
        if 'Rec' in config:
            print("\nRec section:")
            rec_section = config['Rec'] if isinstance(config['Rec'], dict) else {}
            print(f"  cpu_threads: {rec_section.get('cpu_threads', 'NOT SET')}")
            print(f"  enable_mkldnn: {rec_section.get('enable_mkldnn', 'NOT SET')}")
            print(f"  mkldnn_cache_capacity: {rec_section.get('mkldnn_cache_capacity', 'NOT SET')}")
        
        print("\n=== Environment Variables ===")
        print(f"PADDLE_CPU_THREADS: {os.environ.get('PADDLE_CPU_THREADS', 'NOT SET')}")
        print(f"FLAGS_use_mkldnn: {os.environ.get('FLAGS_use_mkldnn', 'NOT SET')}")
        print(f"PADDLE_MKLDNN_CACHE_CAPACITY: {os.environ.get('PADDLE_MKLDNN_CACHE_CAPACITY', 'NOT SET')}")
        print("")
        
        return True
        
    except Exception as e:
        print(f"Error reading config: {e}", file=sys.stderr)
        return False

if __name__ == "__main__":
    config_path = sys.argv[1] if len(sys.argv) > 1 else "/app/ocr_config.yaml"
    verify_config(config_path)
