#!/usr/bin/env python3
"""
Update OCR config YAML with performance settings from environment variables.
This ensures PaddleX serving uses the correct performance parameters.
"""

import os
import sys
import yaml

def update_config(config_path="/app/ocr_config.yaml"):
    """Update config YAML with performance settings from environment."""
    
    cpu_threads = int(os.environ.get("PADDLE_CPU_THREADS", "10"))
    mkldnn_cache = int(os.environ.get("PADDLE_MKLDNN_CACHE_CAPACITY", "20"))
    enable_mkldnn = os.environ.get("FLAGS_use_mkldnn", "1") == "1"
    
    if not os.path.exists(config_path):
        print(f"Warning: Config file not found: {config_path}")
        return False
    
    try:
        with open(config_path, 'r') as f:
            config = yaml.safe_load(f)
        
        updated = False
        
        # Update Global section if it exists
        if 'Global' in config:
            if 'cpu_threads' in config['Global']:
                if config['Global']['cpu_threads'] != cpu_threads:
                    config['Global']['cpu_threads'] = cpu_threads
                    updated = True
            else:
                config['Global']['cpu_threads'] = cpu_threads
                updated = True
            
            if 'enable_mkldnn' in config['Global']:
                if config['Global']['enable_mkldnn'] != enable_mkldnn:
                    config['Global']['enable_mkldnn'] = enable_mkldnn
                    updated = True
            else:
                config['Global']['enable_mkldnn'] = enable_mkldnn
                updated = True
            
            if 'mkldnn_cache_capacity' in config['Global']:
                if config['Global']['mkldnn_cache_capacity'] != mkldnn_cache:
                    config['Global']['mkldnn_cache_capacity'] = mkldnn_cache
                    updated = True
            else:
                config['Global']['mkldnn_cache_capacity'] = mkldnn_cache
                updated = True
        
        # Also check for Det and Rec sections (PaddleOCR structure)
        for section_name in ['Det', 'Rec', 'Cls']:
            if section_name in config:
                section = config[section_name]
                if isinstance(section, dict):
                    if 'cpu_threads' not in section or section['cpu_threads'] != cpu_threads:
                        section['cpu_threads'] = cpu_threads
                        updated = True
                    if 'enable_mkldnn' not in section or section['enable_mkldnn'] != enable_mkldnn:
                        section['enable_mkldnn'] = enable_mkldnn
                        updated = True
                    if 'mkldnn_cache_capacity' not in section or section['mkldnn_cache_capacity'] != mkldnn_cache:
                        section['mkldnn_cache_capacity'] = mkldnn_cache
                        updated = True
        
        # Write back if updated
        if updated:
            with open(config_path, 'w') as f:
                yaml.dump(config, f, default_flow_style=False, sort_keys=False)
            print(f"✓ Updated config: cpu_threads={cpu_threads}, mkldnn_cache={mkldnn_cache}, enable_mkldnn={enable_mkldnn}")
            return True
        else:
            print(f"✓ Config already has correct values: cpu_threads={cpu_threads}, mkldnn_cache={mkldnn_cache}, enable_mkldnn={enable_mkldnn}")
            return True
            
    except Exception as e:
        print(f"Error updating config: {e}", file=sys.stderr)
        return False

if __name__ == "__main__":
    config_path = sys.argv[1] if len(sys.argv) > 1 else "/app/ocr_config.yaml"
    success = update_config(config_path)
    sys.exit(0 if success else 1)
