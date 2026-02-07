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
    det_limit_side_len = int(os.environ.get("PADDLE_DET_LIMIT_SIDE_LEN", "960"))
    precision = os.environ.get("PADDLE_PRECISION", "fp16")
    use_gpu = os.environ.get("PADDLE_USE_GPU", "0") == "1"
    if precision not in ("fp32", "fp16", "int8"):
        precision = "fp16"
    
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
            
            # Update precision (fp16 for speed, fp32 for max accuracy)
            if section.get('precision') != precision:
                section['precision'] = precision
                updated = True
        
        def update_use_gpu(section):
            """Update use_gpu for GPU configs."""
            nonlocal updated
            if not isinstance(section, dict):
                return
            if section.get('use_gpu') != use_gpu:
                section['use_gpu'] = use_gpu
                updated = True
        
        def update_det_section(section):
            """Update detection-specific settings."""
            nonlocal updated
            if not isinstance(section, dict):
                return
            if section.get('det_limit_side_len') != det_limit_side_len:
                section['det_limit_side_len'] = det_limit_side_len
                updated = True
            if section.get('det_limit_type') != 'max':
                section['det_limit_type'] = 'max'
                updated = True
        
        # Update Global section if it exists (old PaddleOCR structure)
        if 'Global' in config:
            update_use_gpu(config['Global'])
            update_section(config['Global'])
        
        # Update Det, Rec, Cls sections (old PaddleOCR structure)
        for section_name in ['Det', 'Rec', 'Cls']:
            if section_name in config:
                update_section(config[section_name])
                if section_name == 'Det':
                    update_det_section(config[section_name])
        
        # Update SubModules structure (PaddleX pipeline structure)
        # These settings should be in inference_config sections for each module
        if 'SubModules' in config:
            for module_name, module_config in config['SubModules'].items():
                if isinstance(module_config, dict):
                    # Ensure inference_config exists and update it
                    if 'inference_config' not in module_config:
                        module_config['inference_config'] = {}
                        updated = True
                    
                    if isinstance(module_config['inference_config'], dict):
                        update_section(module_config['inference_config'])
                    
                    # Also update the module config directly (for backward compatibility)
                    update_section(module_config)
                    
                    # Detection modules: set det_limit_side_len
                    if 'det' in module_name.lower() or 'Det' in str(module_config.get('module_name', '')):
                        update_det_section(module_config)
                    
                    # Check other nested config sections
                    for nested_key in ['predictor_config', 'config']:
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
            print(f"✓ Updated config: use_gpu={use_gpu}, cpu_threads={cpu_threads}, mkldnn_cache={mkldnn_cache}, det_limit_side_len={det_limit_side_len}, precision={precision}")
            return True
        else:
            print(f"✓ Config already has correct values: use_gpu={use_gpu}, cpu_threads={cpu_threads}, mkldnn_cache={mkldnn_cache}, det_limit_side_len={det_limit_side_len}, precision={precision}")
            return True
            
    except Exception as e:
        print(f"Error updating config: {e}", file=sys.stderr)
        return False

if __name__ == "__main__":
    config_path = sys.argv[1] if len(sys.argv) > 1 else "/app/ocr_config.yaml"
    success = update_config(config_path)
    sys.exit(0 if success else 1)
