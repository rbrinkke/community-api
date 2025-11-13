#!/bin/bash
# ============================================================================
# Community API - Test Setup & Teardown
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_config.sh"
source "${SCRIPT_DIR}/test_utils.sh"

# ============================================================================
# SETUP TEST ENVIRONMENT
# ============================================================================

setup_test_environment() {
    log_info "$SYMBOL_ROCKET Setting up test environment..."

    # Create test users
    create_test_users || return 1

    # Create test organization
    create_test_organization || return 1

    # Create test activities
    create_test_activities || return 1

    # Verify setup
    verify_test_setup || return 1

    log_success "$SYMBOL_CHECK Test environment ready!"
    return 0
}

# Create test users in database
create_test_users() {
    log_info "Creating test users..."

    # User 1 (Organizer)
    TEST_USER_1_ID=$(generate_uuid)
    db_query "INSERT INTO ${DB_SCHEMA}.users (user_id, username, email, first_name, last_name, password_hash, is_verified)
              VALUES ('$TEST_USER_1_ID', '$TEST_USER_1_USERNAME', '$TEST_USER_1_EMAIL', 'Test', 'User1', 'test_hash', true)" || return 1

    # User 2 (Member)
    TEST_USER_2_ID=$(generate_uuid)
    db_query "INSERT INTO ${DB_SCHEMA}.users (user_id, username, email, first_name, last_name, password_hash, is_verified)
              VALUES ('$TEST_USER_2_ID', '$TEST_USER_2_USERNAME', '$TEST_USER_2_EMAIL', 'Test', 'User2', 'test_hash', true)" || return 1

    # User 3 (Outsider)
    TEST_USER_3_ID=$(generate_uuid)
    db_query "INSERT INTO ${DB_SCHEMA}.users (user_id, username, email, first_name, last_name, password_hash, is_verified)
              VALUES ('$TEST_USER_3_ID', '$TEST_USER_3_USERNAME', '$TEST_USER_3_EMAIL', 'Test', 'User3', 'test_hash', true)" || return 1

    # Export for use in tests
    export TEST_USER_1_ID TEST_USER_2_ID TEST_USER_3_ID

    log_success "  $SYMBOL_CHECK Created 3 test users"
    return 0
}

# Create test organization
create_test_organization() {
    log_info "Creating test organization..."

    TEST_ORG_ID=$(generate_uuid)
    local org_slug="test-api-org-${TEST_TIMESTAMP}"
    db_query "INSERT INTO ${DB_SCHEMA}.organizations (organization_id, name, slug)
              VALUES ('$TEST_ORG_ID', '$TEST_ORG_NAME', '$org_slug')" || return 1

    # Make user1 organization member
    db_query "INSERT INTO ${DB_SCHEMA}.organization_members (organization_id, user_id)
              VALUES ('$TEST_ORG_ID', '$TEST_USER_1_ID')" || return 1

    export TEST_ORG_ID

    log_success "  $SYMBOL_CHECK Created test organization"
    return 0
}

# Create test activities
create_test_activities() {
    log_info "Creating test activities..."

    # Activity 1 - with all required fields
    TEST_ACTIVITY_1_ID=$(generate_uuid)
    local scheduled_time_1=$(date -u -d "+2 days" '+%Y-%m-%d %H:%M:%S')
    db_query "INSERT INTO ${DB_SCHEMA}.activities
              (activity_id, organizer_user_id, title, description, scheduled_at, max_participants, status)
              VALUES ('$TEST_ACTIVITY_1_ID', '$TEST_USER_1_ID', '$TEST_ACTIVITY_1_NAME',
                      'Test activity 1 for integration tests', '$scheduled_time_1', 10, 'published')" || return 1

    # Activity 2 - with all required fields
    TEST_ACTIVITY_2_ID=$(generate_uuid)
    local scheduled_time_2=$(date -u -d "+3 days" '+%Y-%m-%d %H:%M:%S')
    db_query "INSERT INTO ${DB_SCHEMA}.activities
              (activity_id, organizer_user_id, title, description, scheduled_at, max_participants, status)
              VALUES ('$TEST_ACTIVITY_2_ID', '$TEST_USER_2_ID', '$TEST_ACTIVITY_2_NAME',
                      'Test activity 2 for integration tests', '$scheduled_time_2', 10, 'published')" || return 1

    export TEST_ACTIVITY_1_ID TEST_ACTIVITY_2_ID

    log_success "  $SYMBOL_CHECK Created 2 test activities"
    return 0
}

# Verify test setup
verify_test_setup() {
    log_info "Verifying test setup..."

    # Verify users exist
    for user_id in "$TEST_USER_1_ID" "$TEST_USER_2_ID" "$TEST_USER_3_ID"; do
        if ! db_record_exists "users" "user_id='$user_id'"; then
            log_error "User $user_id not found in database"
            return 1
        fi
    done

    # Verify organization exists
    if ! db_record_exists "organizations" "organization_id='$TEST_ORG_ID'"; then
        log_error "Organization not found in database"
        return 1
    fi

    # Verify activities exist
    for activity_id in "$TEST_ACTIVITY_1_ID" "$TEST_ACTIVITY_2_ID"; do
        if ! db_record_exists "activities" "activity_id='$activity_id'"; then
            log_error "Activity $activity_id not found in database"
            return 1
        fi
    done

    log_success "  $SYMBOL_CHECK All test data verified in database"
    return 0
}

# ============================================================================
# CLEANUP TEST ENVIRONMENT
# ============================================================================

cleanup_test_environment() {
    log_info "Cleaning up test environment..."

    # Delete in reverse order of dependencies
    cleanup_test_data_by_prefix || log_warning "Some test data cleanup failed"

    log_success "$SYMBOL_CHECK Test environment cleaned up"
    return 0
}

# Delete all test data based on prefix
cleanup_test_data_by_prefix() {
    log_info "Deleting test data with prefix: $TEST_PREFIX"

    # Delete communities and related data
    db_query "DELETE FROM ${DB_SCHEMA}.community_activities WHERE community_id IN
              (SELECT community_id FROM ${DB_SCHEMA}.communities WHERE slug LIKE '${TEST_PREFIX}%')" 2>/dev/null

    db_query "DELETE FROM ${DB_SCHEMA}.reactions WHERE target_id IN
              (SELECT post_id FROM ${DB_SCHEMA}.posts WHERE community_id IN
               (SELECT community_id FROM ${DB_SCHEMA}.communities WHERE slug LIKE '${TEST_PREFIX}%'))" 2>/dev/null

    db_query "DELETE FROM ${DB_SCHEMA}.comments WHERE post_id IN
              (SELECT post_id FROM ${DB_SCHEMA}.posts WHERE community_id IN
               (SELECT community_id FROM ${DB_SCHEMA}.communities WHERE slug LIKE '${TEST_PREFIX}%'))" 2>/dev/null

    db_query "DELETE FROM ${DB_SCHEMA}.posts WHERE community_id IN
              (SELECT community_id FROM ${DB_SCHEMA}.communities WHERE slug LIKE '${TEST_PREFIX}%')" 2>/dev/null

    db_query "DELETE FROM ${DB_SCHEMA}.community_members WHERE community_id IN
              (SELECT community_id FROM ${DB_SCHEMA}.communities WHERE slug LIKE '${TEST_PREFIX}%')" 2>/dev/null

    db_query "DELETE FROM ${DB_SCHEMA}.community_tags WHERE community_id IN
              (SELECT community_id FROM ${DB_SCHEMA}.communities WHERE slug LIKE '${TEST_PREFIX}%')" 2>/dev/null

    db_query "DELETE FROM ${DB_SCHEMA}.communities WHERE slug LIKE '${TEST_PREFIX}%'" 2>/dev/null

    # Delete activities
    db_query "DELETE FROM ${DB_SCHEMA}.activity_participants WHERE activity_id IN
              (SELECT activity_id FROM ${DB_SCHEMA}.activities WHERE title LIKE '${TEST_PREFIX}%')" 2>/dev/null

    db_query "DELETE FROM ${DB_SCHEMA}.activities WHERE title LIKE '${TEST_PREFIX}%'" 2>/dev/null

    # Delete organization
    db_query "DELETE FROM ${DB_SCHEMA}.organization_members WHERE organization_id IN
              (SELECT organization_id FROM ${DB_SCHEMA}.organizations WHERE name LIKE '${TEST_PREFIX}%')" 2>/dev/null

    db_query "DELETE FROM ${DB_SCHEMA}.organizations WHERE name LIKE '${TEST_PREFIX}%'" 2>/dev/null

    # Delete users
    db_query "DELETE FROM ${DB_SCHEMA}.users WHERE username LIKE '${TEST_PREFIX}%'" 2>/dev/null

    log_success "  $SYMBOL_CHECK Test data deleted"
    return 0
}

export TEST_SETUP_LOADED="true"
