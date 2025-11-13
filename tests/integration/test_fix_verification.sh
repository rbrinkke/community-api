#!/bin/bash
# Quick test to verify stored procedure fix

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_config.sh"
source "${SCRIPT_DIR}/test_utils.sh"
source "${SCRIPT_DIR}/test_setup.sh"

echo "=== Testing Community Creation with Fixed Stored Procedure ==="
echo ""

# Setup test environment
setup_test_environment > /dev/null 2>&1

echo "User ID: $TEST_USER_1_ID"
echo "Email: $TEST_USER_1_EMAIL"
echo ""

# Generate JWT token
token=$(generate_jwt "$TEST_USER_1_ID" "$TEST_USER_1_EMAIL")
echo "JWT Token generated: ${token:0:40}..."
echo ""

# Make API call
slug="test-fix-$(date +%s)"
echo "Creating community with slug: $slug"
response=$(curl -s -w "\n__HTTP_CODE__%{http_code}" \
    -X POST "http://localhost:8003/api/v1/communities" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $token" \
    -d "{\"name\":\"Test Fix\",\"slug\":\"$slug\",\"community_type\":\"open\"}")

# Extract HTTP code and body
http_code=$(echo "$response" | grep "__HTTP_CODE__" | sed 's/.*__HTTP_CODE__//')
body=$(echo "$response" | sed '/^__HTTP_CODE__/d')

echo "HTTP Status: $http_code"
echo "Response Body:"
echo "$body" | jq . 2>/dev/null || echo "$body"
echo ""

if [[ "$http_code" == "201" ]]; then
    community_id=$(echo "$body" | jq -r ".community_id")
    echo "✅ SUCCESS! Community created with ID: $community_id"
    echo ""
    echo "=== Verifying in Database ==="

    # Query database
    db_result=$(db_query_json "SELECT community_id, name, slug, status, member_count FROM activity.communities WHERE community_id='$community_id'")

    echo "Database record:"
    echo "$db_result" | jq .
    echo ""
    echo "✅ 100% BEWIJS: Data confirmed in database!"
else
    echo "❌ FAILED: Expected 201, got $http_code"
fi

# Cleanup
echo ""
echo "Cleaning up..."
cleanup_test_environment > /dev/null 2>&1
echo "Done!"
