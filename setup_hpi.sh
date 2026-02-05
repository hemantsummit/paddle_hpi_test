#!/bin/bash
# Install PaddleOCR. HPI (fast inference) is Linux x86-64 only—skipped on macOS.

pip install -r requirements.txt

if [[ "$(uname -s)" == "Linux" ]] && [[ "$(uname -m)" == "x86_64" ]]; then
  echo "Installing HPI deps for Linux x86-64..."
  paddleocr install_hpi_deps cpu
else
  echo "Skipping HPI (Linux x86-64 only). API will use standard inference."
fi
