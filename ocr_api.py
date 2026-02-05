#!/usr/bin/env python3
"""
OCR API - Proxy layer over PaddleX serving

Accepts your format (form-data upload, URL) and transforms to/from PaddleX format.
Requires PaddleX serving running (e.g. paddlex --serve --pipeline OCR --port 8080).

API:
    POST /ocr     - Upload image (form-data), returns OCR results + inference time
    POST /ocr/url - Image URL (form field), returns OCR results
    GET  /health  - Health check (probes PaddleX backend)
"""

import base64
import os
import time
import httpx
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from pydantic import BaseModel

PADDLEX_URL = os.environ.get("PADDLEX_SERVING_URL", "http://localhost:8080")
PADDLEX_OCR_URL = f"{PADDLEX_URL.rstrip('/')}/ocr"
PADDLEX_TIMEOUT = float(os.environ.get("PADDLEX_TIMEOUT", "120"))

app = FastAPI(
    title="OCR API",
    description="Proxy over PaddleX serving - form-data upload, URL input",
    version="1.0.0",
)


def _pruned_result_to_text_regions(pruned: dict) -> list[dict]:
    """Convert PaddleX prunedResult to our text_regions format."""
    regions = []
    rec_texts = pruned.get("rec_texts", [])
    rec_scores = pruned.get("rec_scores", [])
    rec_polys = pruned.get("rec_polys", [])
    rec_boxes = pruned.get("rec_boxes", [])

    for i, text in enumerate(rec_texts):
        score = rec_scores[i] if i < len(rec_scores) else 0.0
        poly = rec_polys[i] if i < len(rec_polys) else []
        box = rec_boxes[i] if i < len(rec_boxes) else []
        if hasattr(poly, "tolist"):
            poly = poly.tolist()
        if hasattr(box, "tolist"):
            box = box.tolist()
        regions.append({
            "text": text,
            "confidence": float(score),
            "polygon": poly,
            "bbox": box,
        })
    return regions


async def _call_paddlex(payload: dict) -> tuple[list[dict], float]:
    """Call PaddleX /ocr, return (text_regions, elapsed_ms)."""
    start = time.perf_counter()
    async with httpx.AsyncClient(timeout=PADDLEX_TIMEOUT) as client:
        resp = await client.post(PADDLEX_OCR_URL, json=payload)
    elapsed_ms = (time.perf_counter() - start) * 1000

    if resp.status_code != 200:
        raise HTTPException(502, f"PaddleX error {resp.status_code}: {resp.text[:500]}")

    data = resp.json()
    if data.get("errorCode", 0) != 0:
        raise HTTPException(502, f"PaddleX error: {data.get('errorMsg', 'Unknown')}")

    result = data.get("result", {})
    ocr_results = result.get("ocrResults", [])
    if not ocr_results:
        return [], elapsed_ms

    pruned = ocr_results[0].get("prunedResult", {})
    regions = _pruned_result_to_text_regions(pruned)
    return regions, elapsed_ms


class OCRResponse(BaseModel):
    """OCR API response model."""

    success: bool
    full_text: str
    inference_time_ms: float
    image_path: str | None = None


@app.get("/health")
async def health():
    """Health check - probes PaddleX backend."""
    try:
        async with httpx.AsyncClient(timeout=5) as client:
            await client.get(f"{PADDLEX_URL.rstrip('/')}/docs")
        return {"status": "ok", "paddlex": "reachable"}
    except Exception as e:
        return {"status": "degraded", "paddlex": str(e)}


@app.post("/ocr", response_model=OCRResponse)
async def run_ocr(image: UploadFile = File(...)):
    """
    Run OCR on an uploaded image (form-data).
    Proxies to PaddleX serving with base64-encoded image.
    """
    if not image.content_type or not image.content_type.startswith("image/"):
        raise HTTPException(400, "File must be an image (png, jpg, jpeg, etc.)")

    content = await image.read()
    file_b64 = base64.b64encode(content).decode("ascii")
    payload = {"file": file_b64, "fileType": 1}

    try:
        regions, elapsed_ms = await _call_paddlex(payload)
        full_text = " ".join(r["text"] for r in regions)
        return OCRResponse(
            success=True,
            full_text=full_text,
            inference_time_ms=round(elapsed_ms, 2),
            image_path=image.filename,
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(500, f"OCR failed: {str(e)}")


@app.post("/ocr/url", response_model=OCRResponse)
async def run_ocr_from_url(url: str = Form(..., description="Image URL to process")):
    """
    Run OCR on an image from URL.
    Proxies to PaddleX serving with the image URL.
    """
    payload = {"file": url, "fileType": 1}

    try:
        regions, elapsed_ms = await _call_paddlex(payload)
        full_text = " ".join(r["text"] for r in regions)
        return OCRResponse(
            success=True,
            full_text=full_text,
            inference_time_ms=round(elapsed_ms, 2),
            image_path=url,
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(500, f"OCR failed: {str(e)}")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        app,
        host="0.0.0.0",
        port=int(os.environ.get("PORT", 8000)),
        workers=1,
        timeout_keep_alive=75,
    )
