#!/bin/bash
# ============================================================================
# Community API - Test Configuration
# ============================================================================
# This file contains all configuration, constants, and environment setup
# for the comprehensive integration test suite.
# ============================================================================

# API Configuration
export API_BASE_URL="${API_BASE_URL:-http://localhost:8003}"
export API_V1_PREFIX="/api/v1"
export API_TIMEOUT="${API_TIMEOUT:-30}"

# Database Configuration
export DB_HOST="${DB_HOST:-localhost}"
export DB_PORT="${DB_PORT:-5441}"
export DB_NAME="${DB_NAME:-activitydb}"
export DB_USER="${DB_USER:-postgres}"
export DB_PASSWORD="${DB_PASSWORD:-postgres_secure_password_change_in_prod}"
export DB_SCHEMA="activity"

# JWT Configuration (MUST match community-api configuration)
export JWT_SECRET_KEY="${JWT_SECRET_KEY:-dev-secret-key-change-in-production}"
export JWT_ALGORITHM="HS256"
export JWT_EXPIRY_MINUTES=15

# Test Data Configuration
export TEST_PREFIX="test_api_"
export TEST_TIMESTAMP=$(date +%s)

# Test User IDs (UUIDs - will be created during setup)
export TEST_USER_1_ID=""  # Organizer user
export TEST_USER_1_EMAIL="${TEST_PREFIX}user1_${TEST_TIMESTAMP}@example.com"
export TEST_USER_1_USERNAME="${TEST_PREFIX}user1_${TEST_TIMESTAMP}"

export TEST_USER_2_ID=""  # Member user
export TEST_USER_2_EMAIL="${TEST_PREFIX}user2_${TEST_TIMESTAMP}@example.com"
export TEST_USER_2_USERNAME="${TEST_PREFIX}user2_${TEST_TIMESTAMP}"

export TEST_USER_3_ID=""  # Outsider user (not member)
export TEST_USER_3_EMAIL="${TEST_PREFIX}user3_${TEST_TIMESTAMP}@example.com"
export TEST_USER_3_USERNAME="${TEST_PREFIX}user3_${TEST_TIMESTAMP}"

# Test Organization and Activity IDs (will be created during setup)
export TEST_ORG_ID=""
export TEST_ORG_NAME="${TEST_PREFIX}org_${TEST_TIMESTAMP}"

export TEST_ACTIVITY_1_ID=""
export TEST_ACTIVITY_1_NAME="${TEST_PREFIX}activity1_${TEST_TIMESTAMP}"

export TEST_ACTIVITY_2_ID=""
export TEST_ACTIVITY_2_NAME="${TEST_PREFIX}activity2_${TEST_TIMESTAMP}"

# Test Results Storage
export TEST_RESULTS_DIR="tests/integration/results"
export TEST_RESULTS_JSON="${TEST_RESULTS_DIR}/test_results.json"
export TEST_RESULTS_HTML="${TEST_RESULTS_DIR}/test_report.html"
export TEST_LOG_FILE="${TEST_RESULTS_DIR}/test.log"

# Test Execution Configuration
export VERBOSE="${VERBOSE:-false}"
export DEBUG="${DEBUG:-false}"
export CLEANUP_ON_FAILURE="${CLEANUP_ON_FAILURE:-true}"
export STOP_ON_FIRST_FAILURE="${STOP_ON_FIRST_FAILURE:-false}"

# Color Codes for Terminal Output
export COLOR_RESET="\033[0m"
export COLOR_RED="\033[0;31m"
export COLOR_GREEN="\033[0;32m"
export COLOR_YELLOW="\033[0;33m"
export COLOR_BLUE="\033[0;34m"
export COLOR_MAGENTA="\033[0;35m"
export COLOR_CYAN="\033[0;36m"
export COLOR_WHITE="\033[0;37m"
export COLOR_BOLD="\033[1m"

# Unicode Symbols
export SYMBOL_CHECK="✓"
export SYMBOL_CROSS="✗"
export SYMBOL_ARROW="→"
export SYMBOL_BULLET="•"
export SYMBOL_WARNING="⚠"
export SYMBOL_INFO="ℹ"
export SYMBOL_HOURGLASS="⏳"
export SYMBOL_ROCKET="🚀"
export SYMBOL_TEST="🧪"
export SYMBOL_DATABASE="🗄️"
export SYMBOL_API="🌐"

# Test Statistics (will be updated during execution)
export TOTAL_TESTS=0
export PASSED_TESTS=0
export FAILED_TESTS=0
export SKIPPED_TESTS=0
export START_TIME=""
export END_TIME=""

# Error Codes (matching stored procedure errors)
declare -A ERROR_CODES=(
    ["USER_NOT_FOUND"]="404"
    ["COMMUNITY_NOT_FOUND"]="404"
    ["POST_NOT_FOUND"]="404"
    ["COMMENT_NOT_FOUND"]="404"
    ["ACTIVITY_NOT_FOUND"]="404"
    ["ORGANIZATION_NOT_FOUND"]="404"
    ["PARENT_COMMENT_NOT_FOUND"]="400"
    ["TARGET_NOT_FOUND"]="404"
    ["INSUFFICIENT_PERMISSIONS"]="403"
    ["NOT_MEMBER"]="403"
    ["NOT_COMMUNITY_ORGANIZER"]="403"
    ["NOT_ACTIVITY_ORGANIZER"]="403"
    ["ORGANIZER_CANNOT_LEAVE"]="403"
    ["COMMUNITY_NOT_OPEN"]="403"
    ["NOT_ORGANIZATION_MEMBER"]="403"
    ["SLUG_EXISTS"]="409"
    ["ALREADY_MEMBER"]="400"
    ["COMMUNITY_FULL"]="409"
    ["LINK_ALREADY_EXISTS"]="409"
    ["COMMUNITY_NOT_ACTIVE"]="400"
    ["POST_NOT_PUBLISHED"]="400"
    ["COMMENT_DELETED"]="400"
    ["INVALID_COMMUNITY_TYPE"]="400"
    ["INVALID_TARGET_TYPE"]="400"
)

# Function to initialize test results directory
init_results_dir() {
    mkdir -p "$TEST_RESULTS_DIR"

    # Initialize JSON results file
    cat > "$TEST_RESULTS_JSON" <<EOF
{
  "test_suite": "Community API Integration Tests",
  "start_time": "$(date -Iseconds)",
  "configuration": {
    "api_base_url": "$API_BASE_URL",
    "database": "${DB_HOST}:${DB_PORT}/${DB_NAME}",
    "test_prefix": "$TEST_PREFIX"
  },
  "tests": [],
  "summary": {
    "total": 0,
    "passed": 0,
    "failed": 0,
    "skipped": 0,
    "duration_seconds": 0
  }
}
EOF

    # Initialize log file
    echo "Test Suite Started: $(date)" > "$TEST_LOG_FILE"
    echo "Configuration:" >> "$TEST_LOG_FILE"
    echo "  API: $API_BASE_URL" >> "$TEST_LOG_FILE"
    echo "  Database: ${DB_HOST}:${DB_PORT}/${DB_NAME}" >> "$TEST_LOG_FILE"
    echo "  Test Prefix: $TEST_PREFIX" >> "$TEST_LOG_FILE"
    echo "----------------------------------------" >> "$TEST_LOG_FILE"
}

# Function to get database connection string
get_db_connection() {
    echo "postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
}

# Function to get API endpoint URL
get_api_url() {
    local endpoint=$1
    echo "${API_BASE_URL}${API_V1_PREFIX}${endpoint}"
}

# Function to check if running in CI environment
is_ci_environment() {
    [[ -n "${CI}" ]] || [[ -n "${GITHUB_ACTIONS}" ]] || [[ -n "${GITLAB_CI}" ]]
}

# Function to check if colors should be used
should_use_colors() {
    if is_ci_environment; then
        return 1  # No colors in CI
    fi
    [[ -t 1 ]] && return 0 || return 1
}

# Export configuration status
export TEST_CONFIG_LOADED="true"

# Print configuration summary (if verbose)
if [[ "$VERBOSE" == "true" ]]; then
    echo "Test Configuration Loaded:"
    echo "  API Base URL: $API_BASE_URL"
    echo "  Database: ${DB_HOST}:${DB_PORT}/${DB_NAME}"
    echo "  Test Prefix: $TEST_PREFIX"
    echo "  Results Directory: $TEST_RESULTS_DIR"
fi
