#!/bin/bash
# ============================================================================
# Community API - Example Test Suite
# ============================================================================
# This is an EXAMPLE implementation showing how to write tests
# Use this as a template to build out the full 80-100 test suite
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_config.sh"
source "${SCRIPT_DIR}/test_utils.sh"
source "${SCRIPT_DIR}/test_setup.sh"

# ============================================================================
# EXAMPLE TESTS - COMMUNITIES
# ============================================================================

# Test 1: Create Community (Happy Path)
test_create_community_success() {
    start_test "test_create_community_success"

    log_info "Testing: POST /communities - Create a new community"

    # Generate JWT token for user 1 (organizer)
    local token=$(generate_jwt "$TEST_USER_1_ID" "$TEST_USER_1_EMAIL")

    # Prepare request body
    local slug="test-community-$(date +%s)"
    local request_body=$(jq -n \
        --arg name "Test Community" \
        --arg slug "$slug" \
        --arg description "A test community for integration tests" \
        --arg community_type "open" \
        '{
            name: $name,
            slug: $slug,
            description: $description,
            community_type: $community_type,
            tags: ["test", "integration"],
            max_members: 100
        }')

    # Make API call
    local response=$(api_call POST "/communities" \
        -H "Authorization: Bearer $token" \
        -d "$request_body")

    log_debug "API Response: $response"

    # ===== VERIFY API RESPONSE =====
    assert_status_code "201" "$response" "HTTP status should be 201 Created"

    local community_id=$(echo "$response" | jq -r '.body.community_id')
    assert_not_null "$community_id" "Response should contain community_id"

    assert_json_field "$response" ".body.slug" "$slug" "Slug should match request"
    assert_json_field_not_null "$response" ".body.created_at" "created_at should be set"

    local member_count=$(echo "$response" | jq -r '.body.member_count')
    assert_equals "1" "$member_count" "member_count should be 1 (creator)"

    # ===== VERIFY IN DATABASE =====
    log_info "Verifying data in database..."

    # 1. Check community exists
    local db_community=$(db_query_json "SELECT * FROM ${DB_SCHEMA}.communities WHERE community_id='$community_id'")
    assert_not_null "$db_community" "Community should exist in database"

    local db_name=$(echo "$db_community" | jq -r '.[0].name')
    assert_equals "Test Community" "$db_name" "DB: name should match"

    local db_status=$(echo "$db_community" | jq -r '.[0].status')
    assert_equals "active" "$db_status" "DB: status should be 'active'"

    local db_community_type=$(echo "$db_community" | jq -r '.[0].community_type')
    assert_equals "open" "$db_community_type" "DB: community_type should be 'open'"

    # 2. Check creator is organizer
    local db_membership=$(db_query_json "SELECT * FROM ${DB_SCHEMA}.community_members
                                         WHERE community_id='$community_id' AND user_id='$TEST_USER_1_ID'")
    assert_not_null "$db_membership" "Creator should be member"

    local db_role=$(echo "$db_membership" | jq -r '.[0].role')
    assert_equals "organizer" "$db_role" "DB: Creator role should be 'organizer'"

    local db_member_status=$(echo "$db_membership" | jq -r '.[0].status')
    assert_equals "active" "$db_member_status" "DB: Membership status should be 'active'"

    # 3. Check tags were created
    local db_tags=$(db_query_json "SELECT tag FROM ${DB_SCHEMA}.community_tags WHERE community_id='$community_id' ORDER BY tag")
    local tag_count=$(echo "$db_tags" | jq 'length')
    assert_equals "2" "$tag_count" "DB: Should have 2 tags"

    local tag1=$(echo "$db_tags" | jq -r '.[0].tag')
    assert_equals "integration" "$tag1" "DB: First tag should be 'integration'"

    # 4. Verify member_count accuracy
    local actual_member_count=$(db_query_value "SELECT COUNT(*) FROM ${DB_SCHEMA}.community_members
                                                 WHERE community_id='$community_id' AND status='active'")
    local stored_member_count=$(db_query_value "SELECT member_count FROM ${DB_SCHEMA}.communities
                                                 WHERE community_id='$community_id'")
    assert_equals "$actual_member_count" "$stored_member_count" "DB: member_count should match actual count"

    # Test passed!
    log_success "✅ TEST PASSED: Community created and verified in database"
    ((PASSED_TESTS++))
    return 0
}

# Test 2: Join Community (Happy Path)
test_join_community_success() {
    start_test "test_join_community_success"

    log_info "Testing: POST /communities/{id}/join - User joins a community"

    # First create a community with user 1
    local token1=$(generate_jwt "$TEST_USER_1_ID" "$TEST_USER_1_EMAIL")
    local slug="test-join-$(date +%s)"

    local create_response=$(api_call POST "/communities" \
        -H "Authorization: Bearer $token1" \
        -d "{\"name\":\"Join Test\",\"slug\":\"$slug\",\"community_type\":\"open\"}")

    local community_id=$(echo "$create_response" | jq -r '.body.community_id')
    assert_not_null "$community_id" "Community should be created"

    # Now user 2 joins the community
    local token2=$(generate_jwt "$TEST_USER_2_ID" "$TEST_USER_2_EMAIL")

    local join_response=$(api_call POST "/communities/$community_id/join" \
        -H "Authorization: Bearer $token2")

    log_debug "Join Response: $join_response"

    # ===== VERIFY API RESPONSE =====
    assert_status_code "201" "$join_response" "HTTP status should be 201 Created"

    assert_json_field "$join_response" ".body.community_id" "$community_id" "community_id should match"
    assert_json_field "$join_response" ".body.user_id" "$TEST_USER_2_ID" "user_id should match"
    assert_json_field "$join_response" ".body.role" "member" "Role should be 'member'"
    assert_json_field "$join_response" ".body.status" "active" "Status should be 'active'"
    assert_json_field_not_null "$join_response" ".body.joined_at" "joined_at should be set"

    # ===== VERIFY IN DATABASE =====
    log_info "Verifying membership in database..."

    # 1. Check membership exists
    local db_membership=$(db_query_json "SELECT * FROM ${DB_SCHEMA}.community_members
                                         WHERE community_id='$community_id' AND user_id='$TEST_USER_2_ID'")
    assert_not_null "$db_membership" "Membership should exist in database"

    local db_role=$(echo "$db_membership" | jq -r '.[0].role')
    assert_equals "member" "$db_role" "DB: Role should be 'member'"

    # 2. Check member_count was incremented
    local current_count=$(db_query_value "SELECT member_count FROM ${DB_SCHEMA}.communities
                                          WHERE community_id='$community_id'")
    assert_equals "2" "$current_count" "DB: member_count should be 2 (organizer + new member)"

    # 3. Verify count accuracy
    local actual_count=$(db_query_value "SELECT COUNT(*) FROM ${DB_SCHEMA}.community_members
                                         WHERE community_id='$community_id' AND status='active'")
    assert_equals "$current_count" "$actual_count" "DB: member_count should match actual count"

    log_success "✅ TEST PASSED: User joined community and verified in database"
    ((PASSED_TESTS++))
    return 0
}

# Test 3: Create Post (Happy Path)
test_create_post_success() {
    start_test "test_create_post_success"

    log_info "Testing: POST /communities/{id}/posts - Create a post"

    # Setup: Create community and join as user 2
    local token1=$(generate_jwt "$TEST_USER_1_ID" "$TEST_USER_1_EMAIL")
    local slug="test-post-$(date +%s)"

    local create_response=$(api_call POST "/communities" \
        -H "Authorization: Bearer $token1" \
        -d "{\"name\":\"Post Test\",\"slug\":\"$slug\",\"community_type\":\"open\"}")

    local community_id=$(echo "$create_response" | jq -r '.body.community_id')

    # User 2 joins
    local token2=$(generate_jwt "$TEST_USER_2_ID" "$TEST_USER_2_EMAIL")
    api_call POST "/communities/$community_id/join" -H "Authorization: Bearer $token2" > /dev/null

    # User 2 creates a post
    local post_body=$(jq -n \
        --arg content "This is a test post for integration testing" \
        '{content: $content, content_type: "post", title: "Test Post"}')

    local post_response=$(api_call POST "/communities/$community_id/posts" \
        -H "Authorization: Bearer $token2" \
        -d "$post_body")

    log_debug "Post Response: $post_response"

    # ===== VERIFY API RESPONSE =====
    assert_status_code "201" "$post_response" "HTTP status should be 201 Created"

    local post_id=$(echo "$post_response" | jq -r '.body.post_id')
    assert_not_null "$post_id" "Response should contain post_id"

    assert_json_field "$post_response" ".body.community_id" "$community_id" "community_id should match"
    assert_json_field "$post_response" ".body.author_user_id" "$TEST_USER_2_ID" "author_user_id should match"
    assert_json_field "$post_response" ".body.status" "published" "Status should be 'published'"

    # ===== VERIFY IN DATABASE =====
    log_info "Verifying post in database..."

    # 1. Check post exists
    local db_post=$(db_query_json "SELECT * FROM ${DB_SCHEMA}.posts WHERE post_id='$post_id'")
    assert_not_null "$db_post" "Post should exist in database"

    local db_content=$(echo "$db_post" | jq -r '.[0].content')
    assert_equals "This is a test post for integration testing" "$db_content" "DB: content should match"

    local db_status=$(echo "$db_post" | jq -r '.[0].status')
    assert_equals "published" "$db_status" "DB: status should be 'published'"

    # 2. Check initial counts are zero
    local comment_count=$(echo "$db_post" | jq -r '.[0].comment_count')
    assert_equals "0" "$comment_count" "DB: comment_count should be 0"

    local reaction_count=$(echo "$db_post" | jq -r '.[0].reaction_count')
    assert_equals "0" "$reaction_count" "DB: reaction_count should be 0"

    log_success "✅ TEST PASSED: Post created and verified in database"
    ((PASSED_TESTS++))
    return 0
}

# ============================================================================
# RUN EXAMPLE TESTS
# ============================================================================

run_example_tests() {
    log_info "$(colorize "$COLOR_BOLD$COLOR_CYAN" "Running Example Tests...")"
    echo ""

    # Setup test environment
    log_info "Setting up test environment..."
    if ! setup_test_environment; then
        log_error "Failed to setup test environment"
        return 1
    fi
    echo ""

    PASSED_TESTS=0
    FAILED_TESTS=0
    TOTAL_TESTS=3

    # Run tests
    test_create_community_success || ((FAILED_TESTS++))
    echo ""

    test_join_community_success || ((FAILED_TESTS++))
    echo ""

    test_create_post_success || ((FAILED_TESTS++))
    echo ""

    # Cleanup
    log_info "Cleaning up test environment..."
    cleanup_test_environment
    echo ""

    # Summary
    echo "$(colorize "$COLOR_BOLD$COLOR_CYAN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")"
    log_info "Example Tests Summary:"
    log_info "  Total:  $TOTAL_TESTS"
    log_success "  Passed: $PASSED_TESTS"

    if [[ $FAILED_TESTS -gt 0 ]]; then
        log_error "  Failed: $FAILED_TESTS"
        return 1
    fi

    return 0
}

# If run directly, execute tests
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_example_tests
fi
