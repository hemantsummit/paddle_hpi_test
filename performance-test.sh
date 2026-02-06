#!/bin/bash
# Performance testing script for OCR API
# Tests different configurations and reports inference times

set -e

API_URL="${API_URL:-http://localhost:8000}"
TEST_IMAGE="${TEST_IMAGE:-test_image.png}"

if [ ! -f "$TEST_IMAGE" ]; then
    echo "Error: Test image not found: $TEST_IMAGE"
    echo "Usage: API_URL=http://localhost:8000 TEST_IMAGE=your_image.png ./performance-test.sh"
    exit 1
fi

echo "=== OCR Performance Test ==="
echo "API URL: $API_URL"
echo "Test Image: $TEST_IMAGE"
echo ""

# Test single request
echo "Testing single OCR request..."
START=$(date +%s.%N)
RESPONSE=$(curl -s -X POST "$API_URL/ocr" -F "image=@$TEST_IMAGE")
END=$(date +%s.%N)

ELAPSED=$(echo "$END - $START" | bc)
INFERENCE_TIME=$(echo "$RESPONSE" | grep -o '"inference_time_ms":[0-9.]*' | cut -d: -f2)

echo "Total time: ${ELAPSED}s"
echo "Inference time: ${INFERENCE_TIME}ms"
echo "Response: $RESPONSE" | jq '.' 2>/dev/null || echo "$RESPONSE"
echo ""

# Test multiple requests (warmup + average)
echo "Testing 5 requests (warmup + average)..."
TIMES=()
for i in {1..5}; do
    START=$(date +%s.%N)
    RESPONSE=$(curl -s -X POST "$API_URL/ocr" -F "image=@$TEST_IMAGE")
    END=$(date +%s.%N)
    
    ELAPSED=$(echo "$END - $START" | bc)
    INFERENCE_TIME=$(echo "$RESPONSE" | grep -o '"inference_time_ms":[0-9.]*' | cut -d: -f2)
    TIMES+=($INFERENCE_TIME)
    
    echo "Request $i: ${INFERENCE_TIME}ms (total: ${ELAPSED}s)"
done

# Calculate average (skip first as warmup)
if [ ${#TIMES[@]} -ge 2 ]; then
    SUM=0
    COUNT=0
    for i in "${TIMES[@]:1}"; do
        SUM=$(echo "$SUM + $i" | bc)
        COUNT=$((COUNT + 1))
    done
    AVG=$(echo "scale=2; $SUM / $COUNT" | bc)
    echo ""
    echo "Average inference time (excluding warmup): ${AVG}ms"
fi

echo ""
echo "=== Test Complete ==="
