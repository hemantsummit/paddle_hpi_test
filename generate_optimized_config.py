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
    det_limit_side_len: int = None,
    precision: str = None,
    output_path: str = "/app/ocr_config.yaml",
):
    """Generate optimized OCR config YAML."""
    
    # Get values from environment or use defaults
    cpu_threads = cpu_threads or int(os.environ.get("PADDLE_CPU_THREADS", "10"))
    mkldnn_cache = mkldnn_cache or int(os.environ.get("PADDLE_MKLDNN_CACHE_CAPACITY", "20"))
    enable_mkldnn = enable_mkldnn if enable_mkldnn is not None else os.environ.get("FLAGS_use_mkldnn", "1") == "1"
    det_limit_side_len = det_limit_side_len or int(os.environ.get("PADDLE_DET_LIMIT_SIDE_LEN", "960"))
    precision = precision or os.environ.get("PADDLE_PRECISION", "fp16")
    if precision not in ("fp32", "fp16", "int8"):
        precision = "fp16"
    
    print(f"Generating OCR config:")
    print(f"  CPU Threads: {cpu_threads}")
    print(f"  MKLDNN Enabled: {enable_mkldnn}")
    print(f"  MKLDNN Cache Capacity: {mkldnn_cache}")
    print(f"  Det Limit Side Len: {det_limit_side_len}")
    print(f"  Precision: {precision}")
    print(f"  Output: {output_path}")
    
    # Create PaddleOCR instance: server models (default) for maximum accuracy
    # text_det_limit_side_len=960 (PaddleOCR default for accuracy)
    ocr = PaddleOCR(
        use_doc_orientation_classify=True,
        use_doc_unwarping=False,
        use_textline_orientation=False,
        cpu_threads=cpu_threads,
        enable_mkldnn=enable_mkldnn,
        text_det_limit_side_len=det_limit_side_len,
        text_det_limit_type="max",
    )
    
    # Export config
    ocr.export_paddlex_config_to_yaml(output_path)
    
    print(f"✓ Config generated: {output_path}")
    print("\nTo use this config, ensure it's copied to /app/ocr_config.yaml in the container")
    
    # Update all performance settings in the YAML
    try:
        import yaml
        with open(output_path, 'r') as f:
            config = yaml.safe_load(f)
        
        updated = False
        
        # Update Global section
        if 'Global' in config:
            if config['Global'].get('cpu_threads') != cpu_threads:
                config['Global']['cpu_threads'] = cpu_threads
                updated = True
            if config['Global'].get('enable_mkldnn') != enable_mkldnn:
                config['Global']['enable_mkldnn'] = enable_mkldnn
                updated = True
            if config['Global'].get('mkldnn_cache_capacity') != mkldnn_cache:
                config['Global']['mkldnn_cache_capacity'] = mkldnn_cache
                updated = True
            if config['Global'].get('precision') != precision:
                config['Global']['precision'] = precision
                updated = True
        
        # Update Det and Rec sections
        for section_name in ['Det', 'Rec', 'Cls']:
            if section_name in config and isinstance(config[section_name], dict):
                if config[section_name].get('cpu_threads') != cpu_threads:
                    config[section_name]['cpu_threads'] = cpu_threads
                    updated = True
                if config[section_name].get('enable_mkldnn') != enable_mkldnn:
                    config[section_name]['enable_mkldnn'] = enable_mkldnn
                    updated = True
                if config[section_name].get('mkldnn_cache_capacity') != mkldnn_cache:
                    config[section_name]['mkldnn_cache_capacity'] = mkldnn_cache
                    updated = True
                if config[section_name].get('precision') != precision:
                    config[section_name]['precision'] = precision
                    updated = True
        
        # Update Det-specific: det_limit_side_len (speeds up detection)
        if 'Det' in config and isinstance(config['Det'], dict):
            if config['Det'].get('det_limit_side_len') != det_limit_side_len:
                config['Det']['det_limit_side_len'] = det_limit_side_len
                updated = True
            if config['Det'].get('det_limit_type') != 'max':
                config['Det']['det_limit_type'] = 'max'
                updated = True
        
        # Update SubModules (PaddleX pipeline structure)
        if 'SubModules' in config:
            for module_name, module_config in config['SubModules'].items():
                if isinstance(module_config, dict):
                    # Detection modules: set det_limit_side_len
                    if 'det' in module_name.lower() or 'Det' in str(module_config.get('module_name', '')):
                        if module_config.get('det_limit_side_len') != det_limit_side_len:
                            module_config['det_limit_side_len'] = det_limit_side_len
                            updated = True
                        if module_config.get('det_limit_type') != 'max':
                            module_config['det_limit_type'] = 'max'
                            updated = True
                    # All modules: set precision in inference_config
                    if 'inference_config' in module_config and isinstance(module_config['inference_config'], dict):
                        if module_config['inference_config'].get('precision') != precision:
                            module_config['inference_config']['precision'] = precision
                            updated = True
        
        if updated:
            with open(output_path, 'w') as f:
                yaml.dump(config, f, default_flow_style=False, sort_keys=False)
            print(f"✓ Updated config: cpu_threads={cpu_threads}, mkldnn_cache={mkldnn_cache}, det_limit_side_len={det_limit_side_len}, precision={precision}")
        else:
            print(f"✓ Config values already correct")
    except ImportError:
        print("Warning: PyYAML not available, config values may not be set correctly")
    except Exception as e:
        print(f"Warning: Could not update config automatically: {e}")
        print(f"  Config will be updated at runtime via update_config.py")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate optimized OCR config")
    parser.add_argument("--cpu-threads", type=int, help="Number of CPU threads (default: 10)")
    parser.add_argument("--mkldnn-cache", type=int, help="MKLDNN cache capacity (default: 20)")
    parser.add_argument("--det-limit-side-len", type=int, help="Detection image side limit (default: 960)")
    parser.add_argument("--precision", choices=["fp32", "fp16", "int8"], help="Inference precision (default: fp16)")
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
        det_limit_side_len=getattr(args, 'det_limit_side_len', None),
        precision=getattr(args, 'precision', None),
        output_path=args.output,
    )
