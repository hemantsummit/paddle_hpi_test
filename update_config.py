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
        
        def update_section(section):
            """Update a config section with performance settings."""
            nonlocal updated
            if not isinstance(section, dict):
                return
            
            # Update cpu_threads
            if section.get('cpu_threads') != cpu_threads:
                section['cpu_threads'] = cpu_threads
                updated = True
            
            # Update enable_mkldnn
            if section.get('enable_mkldnn') != enable_mkldnn:
                section['enable_mkldnn'] = enable_mkldnn
                updated = True
            
            # Update mkldnn_cache_capacity
            if section.get('mkldnn_cache_capacity') != mkldnn_cache:
                section['mkldnn_cache_capacity'] = mkldnn_cache
                updated = True
        
        # Update Global section if it exists (old PaddleOCR structure)
        if 'Global' in config:
            update_section(config['Global'])
        
        # Update Det, Rec, Cls sections (old PaddleOCR structure)
        for section_name in ['Det', 'Rec', 'Cls']:
            if section_name in config:
                update_section(config[section_name])
        
        # Update SubModules structure (PaddleX pipeline structure)
        if 'SubModules' in config:
            for module_name, module_config in config['SubModules'].items():
                if isinstance(module_config, dict):
                    # Update the module config directly
                    update_section(module_config)
                    
                    # Also check for 'inference_config' or 'predictor_config' nested sections
                    for nested_key in ['inference_config', 'predictor_config', 'config']:
                        if nested_key in module_config and isinstance(module_config[nested_key], dict):
                            update_section(module_config[nested_key])
        
        # Update SubPipelines structure (if it contains configs)
        if 'SubPipelines' in config:
            for pipeline_name, pipeline_config in config['SubPipelines'].items():
                if isinstance(pipeline_config, dict):
                    # Recursively update any config sections
                    update_section(pipeline_config)
                    if 'SubModules' in pipeline_config:
                        for module_name, module_config in pipeline_config['SubModules'].items():
                            if isinstance(module_config, dict):
                                update_section(module_config)
        
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
