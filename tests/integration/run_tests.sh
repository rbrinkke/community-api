#!/bin/bash
# ============================================================================
# Community API - Integration Test Runner
# ============================================================================
# Main entry point for running the comprehensive test suite
#
# Usage:
#   ./run_tests.sh [options]
#
# Options:
#   --setup         Setup test environment only
#   --cleanup       Cleanup test environment only
#   --no-setup      Skip test environment setup
#   --no-cleanup    Skip cleanup after tests
#   --verbose       Enable verbose output
#   --debug         Enable debug output
#   --category NAME Run specific test category only
#   --help          Show this help message
# ============================================================================

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source dependencies
source "${SCRIPT_DIR}/test_config.sh"
source "${SCRIPT_DIR}/test_utils.sh"
source "${SCRIPT_DIR}/test_setup.sh"

# ============================================================================
# COMMAND LINE ARGUMENTS
# ============================================================================

SKIP_SETUP=false
SKIP_CLEANUP=false
SETUP_ONLY=false
CLEANUP_ONLY=false
TEST_CATEGORY=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --setup)
            SETUP_ONLY=true
            shift
            ;;
        --cleanup)
            CLEANUP_ONLY=true
            shift
            ;;
        --no-setup)
            SKIP_SETUP=true
            shift
            ;;
        --no-cleanup)
            SKIP_CLEANUP=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --debug)
            DEBUG=true
            VERBOSE=true
            shift
            ;;
        --category)
            TEST_CATEGORY="$2"
            shift 2
            ;;
        --help)
            cat << EOF
Community API Integration Test Suite

Usage: $0 [options]

Options:
  --setup         Setup test environment only
  --cleanup       Cleanup test environment only
  --no-setup      Skip test environment setup
  --no-cleanup    Skip cleanup after tests
  --verbose       Enable verbose output
  --debug         Enable debug output
  --category NAME Run specific test category (communities|posts|comments|reactions|activities|integrity)
  --help          Show this help message

Examples:
  $0                              # Run full test suite
  $0 --verbose                    # Run with detailed output
  $0 --category communities       # Run only community tests
  $0 --setup                      # Setup test environment only
  $0 --cleanup                    # Cleanup test environment only
  $0 --no-cleanup                 # Run tests but keep test data
EOF
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            log_info "Use --help for usage information"
            exit 1
            ;;
    esac
done

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    # Print banner
    echo ""
    echo "$(colorize "$COLOR_BOLD$COLOR_CYAN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")"
    echo "$(colorize "$COLOR_BOLD$COLOR_CYAN" " $SYMBOL_TEST  Community API - Comprehensive Integration Test Suite")"
    echo "$(colorize "$COLOR_BOLD$COLOR_CYAN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")"
    echo ""

    # Initialize results directory
    init_results_dir

    # Record start time
    START_TIME=$(date +%s)

    # Verify prerequisites
    log_info "$SYMBOL_INFO Verifying prerequisites..."
    if ! verify_prerequisites; then
        log_error "Prerequisites check failed"
        exit 1
    fi

    # Check API availability
    if ! check_api_available; then
        log_error "API is not available. Please start the API service first."
        exit 1
    fi

    # Check database connectivity
    if ! check_db_connectivity; then
        log_error "Cannot connect to database"
        exit 1
    fi

    echo ""

    # Handle setup-only mode
    if [[ "$SETUP_ONLY" == "true" ]]; then
        log_info "Running in setup-only mode"
        setup_test_environment
        exit $?
    fi

    # Handle cleanup-only mode
    if [[ "$CLEANUP_ONLY" == "true" ]]; then
        log_info "Running in cleanup-only mode"
        cleanup_test_environment
        exit $?
    fi

    # Setup test environment (unless skipped)
    if [[ "$SKIP_SETUP" == "false" ]]; then
        log_info "$(colorize "$COLOR_BOLD" "[SETUP] Initializing test environment...")"
        if ! setup_test_environment; then
            log_error "Test environment setup failed"
            exit 1
        fi
        echo ""
    else
        log_warning "Skipping test environment setup"
        echo ""
    fi

    # Run test suite
    log_info "$(colorize "$COLOR_BOLD" "[TESTS] Running test suite...")"
    echo ""

    # TODO: Source and run test_suite.sh based on category
    # For now, just placeholder
    log_info "Test suite execution will be implemented in test_suite.sh"
    log_info "This includes:"
    log_info "  - Communities tests (25)"
    log_info "  - Posts tests (20)"
    log_info "  - Comments tests (20)"
    log_info "  - Reactions tests (15)"
    log_info "  - Activity Links tests (5)"
    log_info "  - Data Integrity tests (15)"

    echo ""

    # Cleanup test environment (unless skipped)
    if [[ "$SKIP_CLEANUP" == "false" ]]; then
        log_info "$(colorize "$COLOR_BOLD" "[CLEANUP] Removing test data...")"
        cleanup_test_environment
        echo ""
    else
        log_warning "Skipping test cleanup - test data will remain in database"
        echo ""
    fi

    # Record end time
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))

    # Print summary
    echo "$(colorize "$COLOR_BOLD$COLOR_CYAN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")"
    echo "$(colorize "$COLOR_BOLD$COLOR_CYAN" " Test Suite Summary")"
    echo "$(colorize "$COLOR_BOLD$COLOR_CYAN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")"
    echo ""
    log_info "Duration: ${DURATION}s"
    log_info "Test data prefix: $TEST_PREFIX"
    log_info "Results directory: $TEST_RESULTS_DIR"
    echo ""
    echo "$(colorize "$COLOR_BOLD$COLOR_GREEN" "$SYMBOL_CHECK Framework ready! Add tests to test_suite.sh to complete implementation.")"
    echo ""

    return 0
}

# Run main function
main "$@"
