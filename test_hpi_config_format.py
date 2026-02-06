#!/usr/bin/env python3
"""
Test script to verify HPI config format for PaddleX.
This helps determine the correct format before deploying.
"""

import json
import sys
import subprocess

def test_hpi_config_format():
    """Test different HPI config formats to see what PaddleX accepts."""
    
    cpu_threads = 4
    mkldnn_cache = 30
    enable_mkldnn = True
    
    # Create test config
    hpi_config = {
        "cpu_threads": cpu_threads,
        "mkldnn_cache_capacity": mkldnn_cache,
        "enable_mkldnn": enable_mkldnn,
        "ir_optim": True,
        "enable_memory_optim": True,
    }
    
    # Save to file
    config_file = "/tmp/test_hpi_config.json"
    with open(config_file, 'w') as f:
        json.dump(hpi_config, f, indent=2)
    
    print("Created test HPI config:")
    print(json.dumps(hpi_config, indent=2))
    print()
    
    # Test 1: Try to see what paddlex --help says about --hpi_config
    print("Test 1: Checking paddlex --help for --hpi_config usage...")
    try:
        result = subprocess.run(
            ["paddlex", "--serve", "--help"],
            capture_output=True,
            text=True,
            timeout=10
        )
        if "--hpi_config" in result.stdout or "--hpi_config" in result.stderr:
            print("Found --hpi_config in help:")
            lines = (result.stdout + result.stderr).split('\n')
            for i, line in enumerate(lines):
                if "--hpi_config" in line:
                    print(f"  {line}")
                    # Print a few lines after for context
                    for j in range(1, 3):
                        if i + j < len(lines):
                            print(f"  {lines[i+j]}")
    except Exception as e:
        print(f"Could not check help: {e}")
    
    print()
    print("Note: The actual format will be tested when running the container.")
    print("If file path doesn't work, we may need to pass JSON string directly.")

if __name__ == "__main__":
    test_hpi_config_format()
