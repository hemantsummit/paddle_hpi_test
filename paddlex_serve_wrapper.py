#!/usr/bin/env python3
"""
Wrapper for paddlex --serve that properly formats --hpi_config argument.
PaddleX expects --hpi_config to be a JSON string/dict, not a file path.
"""

import os
import sys
import json
import subprocess

def main():
    """Run paddlex --serve with properly formatted HPI config."""
    
    # Parse arguments, looking for --hpi_config
    args = sys.argv[1:]
    hpi_config_file = None
    hpi_config_index = -1
    
    # Find --hpi_config argument
    for i, arg in enumerate(args):
        if arg == "--hpi_config" and i + 1 < len(args):
            hpi_config_file = args[i + 1]
            hpi_config_index = i
            break
    
    # If HPI config file is specified, read it and replace with Python dict string
    # PaddleX uses ast.literal_eval which expects Python literals, not JSON
    if hpi_config_file and os.path.exists(hpi_config_file):
        try:
            with open(hpi_config_file, 'r') as f:
                hpi_config_dict = json.load(f)
            
            # Convert dict to Python literal string format (ast.literal_eval compatible)
            # repr() gives us Python dict format: {'key': True} instead of {"key": true}
            hpi_config_python = repr(hpi_config_dict)
            
            # Replace file path with Python dict string in args
            args[hpi_config_index + 1] = hpi_config_python
            
            print(f"Loaded HPI config from {hpi_config_file}")
            print(f"HPI config (Python format): {hpi_config_python}")
        except Exception as e:
            print(f"Warning: Could not load HPI config from {hpi_config_file}: {e}", file=sys.stderr)
            # Remove --hpi_config and its value if we can't load it
            args.pop(hpi_config_index)
            if hpi_config_index < len(args):
                args.pop(hpi_config_index)
    
    # Build paddlex command
    paddlex_cmd = ["paddlex"] + args
    
    print(f"Executing: {' '.join(paddlex_cmd[:6])}...")  # Show first few args
    
    # Run paddlex
    sys.exit(subprocess.call(paddlex_cmd))

if __name__ == "__main__":
    main()
