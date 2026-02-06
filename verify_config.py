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
        
        def print_section(name, section):
            """Print performance settings from a section."""
            if isinstance(section, dict):
                print(f"\n{name}:")
                print(f"  cpu_threads: {section.get('cpu_threads', 'NOT SET')}")
                print(f"  enable_mkldnn: {section.get('enable_mkldnn', 'NOT SET')}")
                print(f"  mkldnn_cache_capacity: {section.get('mkldnn_cache_capacity', 'NOT SET')}")
        
        # Check Global section (old structure)
        if 'Global' in config:
            print_section("Global section", config['Global'])
        
        # Check Det, Rec, Cls sections (old structure)
        for section_name in ['Det', 'Rec', 'Cls']:
            if section_name in config:
                print_section(f"{section_name} section", config[section_name] if isinstance(config[section_name], dict) else {})
        
        # Check SubModules structure (PaddleX pipeline structure)
        if 'SubModules' in config:
            print("\nSubModules:")
            for module_name, module_config in config['SubModules'].items():
                if isinstance(module_config, dict):
                    print_section(f"  {module_name}", module_config)
                    # Check nested configs
                    for nested_key in ['inference_config', 'predictor_config', 'config']:
                        if nested_key in module_config:
                            print_section(f"    {module_name}.{nested_key}", module_config[nested_key] if isinstance(module_config[nested_key], dict) else {})
        
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
