#!/bin/bash
# ============================================================================
# Community API - Test Utilities
# ============================================================================
# Comprehensive utility functions for testing:
# - JWT generation (pure bash + openssl)
# - API calls with error handling
# - Database queries
# - Assertion functions
# - Logging and reporting
# ============================================================================

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_config.sh"

# ============================================================================
# JWT TOKEN GENERATION (Pure Bash + OpenSSL)
# ============================================================================

# Base64URL encode function (RFC 4648)
base64url_encode() {
    local input="$1"
    echo -n "$input" | openssl base64 -e -A | tr '+/' '-_' | tr -d '='
}

# Generate JWT token using Python wrapper (same library as API)
# Usage: generate_jwt <user_id> <email> [subscription_level] [ghost_mode] [org_id]
generate_jwt() {
    local user_id="$1"
    local email="$2"
    local subscription_level="${3:-free}"
    local ghost_mode="${4:-false}"
    local org_id="${5:-null}"

    # Validate inputs
    if [[ -z "$user_id" ]] || [[ -z "$email" ]]; then
        log_error "generate_jwt: user_id and email are required"
        return 1
    fi

    # Use Python wrapper script to generate JWT
    local token=$(python3 "${SCRIPT_DIR}/jwt_generate.py" \
        "$user_id" \
        "$email" \
        "$subscription_level" \
        "$ghost_mode" \
        "$org_id" \
        "$JWT_EXPIRY_MINUTES" 2>/dev/null)

    if [[ -z "$token" ]]; then
        log_error "Failed to generate JWT token"
        return 1
    fi

    echo "$token"
}

# ============================================================================
# API CALL FUNCTIONS
# ============================================================================

# Make API call with comprehensive error handling
# Usage: api_call <method> <endpoint> [additional curl args...]
# Returns JSON: {"status_code": 200, "body": {...}, "headers": {...}}
api_call() {
    local method="$1"
    local endpoint="$2"
    shift 2
    local curl_args=("$@")

    local url=$(get_api_url "$endpoint")
    local temp_file=$(mktemp)
    local headers_file=$(mktemp)

    # Make request and capture response
    local http_code=$(curl -s -w "%{http_code}" \
        -X "$method" \
        "$url" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        --max-time "$API_TIMEOUT" \
        -D "$headers_file" \
        -o "$temp_file" \
        "${curl_args[@]}")

    local curl_exit_code=$?

    # Check for curl errors
    if [[ $curl_exit_code -ne 0 ]]; then
        log_error "API call failed: curl exit code $curl_exit_code"
        echo '{"status_code": 0, "error": "curl_failed", "body": null}'
        rm -f "$temp_file" "$headers_file"
        return 1
    fi

    # Read response body
    local body=$(cat "$temp_file")

    # Try to parse as JSON, if fails return as string
    if echo "$body" | jq empty 2>/dev/null; then
        local body_json=$(echo "$body" | jq -c '.')
    else
        local body_json=$(jq -n --arg body "$body" '{raw: $body}')
    fi

    # Create response object
    local response=$(jq -n \
        --argjson status_code "$http_code" \
        --argjson body "$body_json" \
        '{status_code: $status_code, body: $body}')

    # Clean up
    rm -f "$temp_file" "$headers_file"

    # Log if debug enabled
    if [[ "$DEBUG" == "true" ]]; then
        log_debug "API $method $endpoint -> $http_code"
        log_debug "Response: $(echo "$response" | jq -c '.')"
    fi

    echo "$response"
}

# ============================================================================
# DATABASE QUERY FUNCTIONS
# ============================================================================

# Execute database query and return JSON result
# Usage: db_query <sql_query>
db_query() {
    local query="$1"

    if [[ -z "$query" ]]; then
        log_error "db_query: SQL query is required"
        return 1
    fi

    local result=$(PGPASSWORD="$DB_PASSWORD" psql \
        -h "$DB_HOST" \
        -p "$DB_PORT" \
        -U "$DB_USER" \
        -d "$DB_NAME" \
        -t \
        -A \
        -F ',' \
        --no-psqlrc \
        -c "$query" 2>&1)

    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        log_error "Database query failed: $result"
        return 1
    fi

    # Log if debug enabled
    if [[ "$DEBUG" == "true" ]]; then
        log_debug "DB Query: $query"
        log_debug "Result: $result"
    fi

    echo "$result"
}

# Execute database query and return JSON array
# Usage: db_query_json <sql_query>
db_query_json() {
    local query="$1"

    # Modify query to return JSON
    local json_query="SELECT json_agg(row_to_json(t)) FROM ($query) t;"

    local result=$(PGPASSWORD="$DB_PASSWORD" psql \
        -h "$DB_HOST" \
        -p "$DB_PORT" \
        -U "$DB_USER" \
        -d "$DB_NAME" \
        -t \
        -A \
        --no-psqlrc \
        -c "$json_query" 2>&1)

    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        log_error "Database query failed: $result"
        return 1
    fi

    # Return empty array if null
    if [[ "$result" == "" ]] || [[ "$result" == "null" ]]; then
        echo "[]"
    else
        echo "$result"
    fi
}

# Execute database query and return single value
# Usage: db_query_value <sql_query>
db_query_value() {
    local query="$1"

    local result=$(db_query "$query")

    # Remove whitespace and return
    echo "$result" | tr -d '[:space:]'
}

# Check if record exists in database
# Usage: db_record_exists <table> <where_clause>
db_record_exists() {
    local table="$1"
    local where_clause="$2"

    local count=$(db_query_value "SELECT COUNT(*) FROM ${DB_SCHEMA}.${table} WHERE ${where_clause}")

    [[ "$count" -gt 0 ]]
}

# ============================================================================
# ASSERTION FUNCTIONS
# ============================================================================

# Global assertion state
CURRENT_TEST_NAME=""
CURRENT_TEST_ASSERTIONS=0
CURRENT_TEST_FAILURES=0

# Start a new test
start_test() {
    local test_name="$1"
    CURRENT_TEST_NAME="$test_name"
    CURRENT_TEST_ASSERTIONS=0
    CURRENT_TEST_FAILURES=0

    log_info "Starting test: $test_name"
}

# Assert equals
# Usage: assert_equals <expected> <actual> [message]
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"

    ((CURRENT_TEST_ASSERTIONS++))

    if [[ "$expected" == "$actual" ]]; then
        log_success "  $SYMBOL_CHECK $message"
        return 0
    else
        ((CURRENT_TEST_FAILURES++))
        log_error "  $SYMBOL_CROSS $message"
        log_error "    Expected: $expected"
        log_error "    Actual:   $actual"
        return 1
    fi
}

# Assert not equals
# Usage: assert_not_equals <not_expected> <actual> [message]
assert_not_equals() {
    local not_expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"

    ((CURRENT_TEST_ASSERTIONS++))

    if [[ "$not_expected" != "$actual" ]]; then
        log_success "  $SYMBOL_CHECK $message"
        return 0
    else
        ((CURRENT_TEST_FAILURES++))
        log_error "  $SYMBOL_CROSS $message"
        log_error "    Should not equal: $not_expected"
        log_error "    Actual:           $actual"
        return 1
    fi
}

# Assert not null
# Usage: assert_not_null <value> [message]
assert_not_null() {
    local value="$1"
    local message="${2:-Value should not be null}"

    ((CURRENT_TEST_ASSERTIONS++))

    if [[ -n "$value" ]] && [[ "$value" != "null" ]]; then
        log_success "  $SYMBOL_CHECK $message"
        return 0
    else
        ((CURRENT_TEST_FAILURES++))
        log_error "  $SYMBOL_CROSS $message (value is null or empty)"
        return 1
    fi
}

# Assert null
# Usage: assert_null <value> [message]
assert_null() {
    local value="$1"
    local message="${2:-Value should be null}"

    ((CURRENT_TEST_ASSERTIONS++))

    if [[ -z "$value" ]] || [[ "$value" == "null" ]]; then
        log_success "  $SYMBOL_CHECK $message"
        return 0
    else
        ((CURRENT_TEST_FAILURES++))
        log_error "  $SYMBOL_CROSS $message (value is: $value)"
        return 1
    fi
}

# Assert contains
# Usage: assert_contains <haystack> <needle> [message]
assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should contain substring}"

    ((CURRENT_TEST_ASSERTIONS++))

    if [[ "$haystack" == *"$needle"* ]]; then
        log_success "  $SYMBOL_CHECK $message"
        return 0
    else
        ((CURRENT_TEST_FAILURES++))
        log_error "  $SYMBOL_CROSS $message"
        log_error "    Haystack: $haystack"
        log_error "    Needle:   $needle"
        return 1
    fi
}

# Assert HTTP status code
# Usage: assert_status_code <expected_code> <response_json> [message]
assert_status_code() {
    local expected="$1"
    local response="$2"
    local message="${3:-HTTP status code mismatch}"

    local actual=$(echo "$response" | jq -r '.status_code')
    assert_equals "$expected" "$actual" "$message"
}

# Assert JSON field equals
# Usage: assert_json_field <response_json> <jq_path> <expected_value> [message]
assert_json_field() {
    local json="$1"
    local jq_path="$2"
    local expected="$3"
    local message="${4:-JSON field mismatch: $jq_path}"

    local actual=$(echo "$json" | jq -r "$jq_path")
    assert_equals "$expected" "$actual" "$message"
}

# Assert JSON field is not null
# Usage: assert_json_field_not_null <response_json> <jq_path> [message]
assert_json_field_not_null() {
    local json="$1"
    local jq_path="$2"
    local message="${3:-JSON field should not be null: $jq_path}"

    local value=$(echo "$json" | jq -r "$jq_path")
    assert_not_null "$value" "$message"
}

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

# Get colored output if supported
colorize() {
    local color="$1"
    local text="$2"

    if should_use_colors; then
        echo -e "${color}${text}${COLOR_RESET}"
    else
        echo "$text"
    fi
}

# Log success message
log_success() {
    local message="$1"
    echo "$(colorize "$COLOR_GREEN" "$message")"
    echo "[SUCCESS] $message" >> "$TEST_LOG_FILE"
}

# Log error message
log_error() {
    local message="$1"
    echo "$(colorize "$COLOR_RED" "$message")" >&2
    echo "[ERROR] $message" >> "$TEST_LOG_FILE"
}

# Log warning message
log_warning() {
    local message="$1"
    echo "$(colorize "$COLOR_YELLOW" "$message")"
    echo "[WARNING] $message" >> "$TEST_LOG_FILE"
}

# Log info message
log_info() {
    local message="$1"
    echo "$(colorize "$COLOR_CYAN" "$message")"
    echo "[INFO] $message" >> "$TEST_LOG_FILE"
}

# Log debug message
log_debug() {
    local message="$1"
    if [[ "$DEBUG" == "true" ]]; then
        echo "$(colorize "$COLOR_MAGENTA" "[DEBUG] $message")"
        echo "[DEBUG] $message" >> "$TEST_LOG_FILE"
    fi
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Generate UUID
generate_uuid() {
    if command -v uuidgen &> /dev/null; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    else
        # Fallback: use Python
        python3 -c "import uuid; print(uuid.uuid4())"
    fi
}

# Get current timestamp in ISO 8601 format
get_timestamp() {
    date -Iseconds
}

# Sleep with message
sleep_with_message() {
    local seconds="$1"
    local message="${2:-Waiting}"

    log_info "$message ($seconds seconds)..."
    sleep "$seconds"
}

# Check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Verify prerequisites
verify_prerequisites() {
    local missing_commands=()

    local required_commands=("curl" "jq" "psql" "openssl" "base64")

    for cmd in "${required_commands[@]}"; do
        if ! command_exists "$cmd"; then
            missing_commands+=("$cmd")
        fi
    done

    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing_commands[*]}"
        log_error "Please install missing dependencies"
        return 1
    fi

    log_success "All prerequisites verified"
    return 0
}

# Check API availability
check_api_available() {
    log_info "Checking API availability at $API_BASE_URL..."

    # Health endpoint doesn't use API_V1_PREFIX
    local url="${API_BASE_URL}/health"
    local temp_file=$(mktemp)

    local http_code=$(curl -s -w "%{http_code}" \
        -X GET \
        "$url" \
        -H "Accept: application/json" \
        --max-time "$API_TIMEOUT" \
        -o "$temp_file")

    rm -f "$temp_file"

    if [[ "$http_code" == "200" ]]; then
        log_success "API is available"
        return 0
    else
        log_error "API is not available (status: $http_code)"
        return 1
    fi
}

# Check database connectivity
check_db_connectivity() {
    log_info "Checking database connectivity..."

    local result=$(db_query_value "SELECT 1")

    if [[ "$result" == "1" ]]; then
        log_success "Database connection successful"
        return 0
    else
        log_error "Database connection failed"
        return 1
    fi
}

# Export utility functions loaded status
export TEST_UTILS_LOADED="true"
