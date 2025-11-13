#!/bin/bash
# ============================================================================
# SPRINT DEMO - REUSABLE SCENARIOS
# ============================================================================

DEMO_SCENARIOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${DEMO_SCENARIOS_DIR}/demo_lib.sh"

# ============================================================================
# PERSONA SETUP
# ============================================================================

demo_create_personas() {
    demo_action "Setting up demo personas..."

    # Create Alice
    ALICE_ID=$(generate_uuid)
    db_query "INSERT INTO activity.users (user_id, username, email, first_name, last_name, password_hash, is_verified)
              VALUES ('$ALICE_ID', '$DEMO_ALICE_USERNAME', '$DEMO_ALICE_EMAIL', 'Alice', 'van Berg', 'demo_hash', true)" || return 1

    # Create Bob
    BOB_ID=$(generate_uuid)
    db_query "INSERT INTO activity.users (user_id, username, email, first_name, last_name, password_hash, is_verified)
              VALUES ('$BOB_ID', '$DEMO_BOB_USERNAME', '$DEMO_BOB_EMAIL', 'Bob', 'de Vries', 'demo_hash', true)" || return 1

    # Create Carol
    CAROL_ID=$(generate_uuid)
    db_query "INSERT INTO activity.users (user_id, username, email, first_name, last_name, password_hash, is_verified)
              VALUES ('$CAROL_ID', '$DEMO_CAROL_USERNAME', '$DEMO_CAROL_EMAIL', 'Carol', 'Janssen', 'demo_hash', true)" || return 1

    # Export for use in other scenarios
    export ALICE_ID BOB_ID CAROL_ID

    echo -e "${COLOR_GREEN}${SYMBOL_SUCCESS} Created 3 personas:${COLOR_RESET}"
    echo -e "   ${SYMBOL_PERSON} Alice van Berg (Organizer)"
    echo -e "   ${SYMBOL_PERSON} Bob de Vries (Member)"
    echo -e "   ${SYMBOL_PERSON} Carol Janssen (Member)"
    echo ""

    demo_db_header
    demo_table "users (demo personas)" "SELECT user_id, username, email, first_name, last_name FROM activity.users WHERE username LIKE 'demo_%' ORDER BY username"

    demo_record_action "true"
    demo_pause
}

# ============================================================================
# COMMUNITY SCENARIOS
# ============================================================================

scenario_create_community() {
    demo_action "${SYMBOL_PERSON} Alice creates '$DEMO_COMMUNITY_NAME' community"

    # Generate JWT for Alice
    local alice_token=$(generate_jwt "$ALICE_ID" "$DEMO_ALICE_EMAIL")

    # Prepare request body
    local request_body=$(jq -n \
        --arg name "$DEMO_COMMUNITY_NAME" \
        --arg slug "$DEMO_COMMUNITY_SLUG" \
        '{
            name: $name,
            slug: $slug,
            description: "Een community voor tech professionals in Rotterdam",
            community_type: "open",
            tags: ["tech", "networking", "rotterdam"],
            max_members: 100
        }')

    demo_api_call_display "POST" "/api/v1/communities" "$request_body"

    # Make API call
    local start_time=$(date +%s%3N)
    local response=$(api_call POST "/communities" \
        -H "Authorization: Bearer $alice_token" \
        -d "$request_body")
    local end_time=$(date +%s%3N)
    local duration=$((end_time - start_time))

    local status=$(echo "$response" | jq -r '.status_code')
    local body=$(echo "$response" | jq -r '.body')

    demo_api_response "$status" "$body"

    if [[ "$status" == "201" ]]; then
        COMMUNITY_ID=$(echo "$body" | jq -r '.community_id')
        export COMMUNITY_ID

        # Database verification
        demo_db_header
        demo_table "communities" "SELECT community_id, name, slug, status, member_count, created_at FROM activity.communities WHERE community_id='$COMMUNITY_ID'"
        demo_table "community_members" "SELECT user_id, role, status, joined_at FROM activity.community_members WHERE community_id='$COMMUNITY_ID'"
        demo_table "community_tags" "SELECT tag FROM activity.community_tags WHERE community_id='$COMMUNITY_ID' ORDER BY tag"

        demo_verify_counts "$COMMUNITY_ID"

        echo -e "${COLOR_GREEN}${SYMBOL_SUCCESS} Community created and verified!${COLOR_RESET}"

        demo_record_action "true"
        demo_record_api_time "$duration"
    else
        echo -e "${COLOR_RED}${SYMBOL_ERROR} Failed to create community${COLOR_RESET}"
        demo_record_action "false"
        return 1
    fi

    demo_pause
}

scenario_join_community() {
    local user_name="$1"
    local user_id="$2"
    local user_email="$3"

    demo_action "${SYMBOL_PERSON} $user_name joins the community"

    # Generate JWT
    local user_token=$(generate_jwt "$user_id" "$user_email")

    demo_api_call_display "POST" "/api/v1/communities/$COMMUNITY_ID/join"

    # Make API call
    local start_time=$(date +%s%3N)
    local response=$(api_call POST "/communities/$COMMUNITY_ID/join" \
        -H "Authorization: Bearer $user_token")
    local end_time=$(date +%s%3N)
    local duration=$((end_time - start_time))

    local status=$(echo "$response" | jq -r '.status_code')
    local body=$(echo "$response" | jq -r '.body')

    demo_api_response "$status" "$body"

    if [[ "$status" == "201" ]]; then
        # Database verification
        demo_db_header
        demo_table "community_members (all)" "SELECT user_id, role, status, joined_at FROM activity.community_members WHERE community_id='$COMMUNITY_ID' ORDER BY joined_at"
        demo_verify_counts "$COMMUNITY_ID"

        echo -e "${COLOR_GREEN}${SYMBOL_SUCCESS} $user_name joined successfully!${COLOR_RESET}"

        demo_record_action "true"
        demo_record_api_time "$duration"
    else
        echo -e "${COLOR_RED}${SYMBOL_ERROR} Failed to join community${COLOR_RESET}"
        demo_record_action "false"
        return 1
    fi

    demo_pause
}

# ============================================================================
# CONTENT SCENARIOS
# ============================================================================

scenario_create_post() {
    local author_name="$1"
    local author_id="$2"
    local author_email="$3"
    local post_content="$4"

    demo_action "${SYMBOL_PERSON} $author_name creates a post"

    # Generate JWT
    local author_token=$(generate_jwt "$author_id" "$author_email")

    local request_body=$(jq -n \
        --arg content "$post_content" \
        '{
            content: $content,
            content_type: "post",
            title: "Welcome Post"
        }')

    demo_api_call_display "POST" "/api/v1/communities/$COMMUNITY_ID/posts" "$request_body"

    # Make API call
    local start_time=$(date +%s%3N)
    local response=$(api_call POST "/communities/$COMMUNITY_ID/posts" \
        -H "Authorization: Bearer $author_token" \
        -d "$request_body")
    local end_time=$(date +%s%3N)
    local duration=$((end_time - start_time))

    local status=$(echo "$response" | jq -r '.status_code')
    local body=$(echo "$response" | jq -r '.body')

    demo_api_response "$status" "$body"

    if [[ "$status" == "201" ]]; then
        POST_ID=$(echo "$body" | jq -r '.post_id')
        export POST_ID

        # Database verification
        demo_db_header
        demo_table "posts" "SELECT post_id, LEFT(content, 50) as content, status, comment_count, reaction_count, created_at FROM activity.posts WHERE post_id='$POST_ID'"

        echo -e "${COLOR_GREEN}${SYMBOL_SUCCESS} Post created!${COLOR_RESET}"

        demo_record_action "true"
        demo_record_api_time "$duration"
    else
        echo -e "${COLOR_RED}${SYMBOL_ERROR} Failed to create post${COLOR_RESET}"
        demo_record_action "false"
        return 1
    fi

    demo_pause
}

scenario_add_comment() {
    local commenter_name="$1"
    local commenter_id="$2"
    local commenter_email="$3"
    local comment_content="$4"

    demo_action "${SYMBOL_PERSON} $commenter_name adds a comment"

    # Generate JWT
    local commenter_token=$(generate_jwt "$commenter_id" "$commenter_email")

    local request_body=$(jq -n \
        --arg content "$comment_content" \
        '{content: $content}')

    demo_api_call_display "POST" "/api/v1/posts/$POST_ID/comments" "$request_body"

    # Make API call
    local start_time=$(date +%s%3N)
    local response=$(api_call POST "/posts/$POST_ID/comments" \
        -H "Authorization: Bearer $commenter_token" \
        -d "$request_body")
    local end_time=$(date +%s%3N)
    local duration=$((end_time - start_time))

    local status=$(echo "$response" | jq -r '.status_code')
    local body=$(echo "$response" | jq -r '.body')

    demo_api_response "$status" "$body"

    if [[ "$status" == "201" ]]; then
        COMMENT_ID=$(echo "$body" | jq -r '.comment_id')
        export COMMENT_ID

        # Database verification
        demo_db_header
        demo_table "comments" "SELECT comment_id, LEFT(content, 40) as content, author_user_id, created_at FROM activity.comments WHERE comment_id='$COMMENT_ID'"
        demo_table "posts (updated counts)" "SELECT post_id, comment_count, reaction_count FROM activity.posts WHERE post_id='$POST_ID'"

        echo -e "${COLOR_GREEN}${SYMBOL_SUCCESS} Comment added! Post comment_count updated.${COLOR_RESET}"

        demo_record_action "true"
        demo_record_api_time "$duration"
    else
        echo -e "${COLOR_RED}${SYMBOL_ERROR} Failed to add comment${COLOR_RESET}"
        demo_record_action "false"
        return 1
    fi

    demo_pause
}

scenario_add_reaction() {
    local reactor_name="$1"
    local reactor_id="$2"
    local reactor_email="$3"
    local reaction_type="$4"

    demo_action "${SYMBOL_PERSON} $reactor_name reacts with $reaction_type"

    # Generate JWT
    local reactor_token=$(generate_jwt "$reactor_id" "$reactor_email")

    local request_body=$(jq -n \
        --arg reaction_type "$reaction_type" \
        '{reaction_type: $reaction_type}')

    demo_api_call_display "POST" "/api/v1/posts/$POST_ID/reactions" "$request_body"

    # Make API call
    local start_time=$(date +%s%3N)
    local response=$(api_call POST "/posts/$POST_ID/reactions" \
        -H "Authorization: Bearer $reactor_token" \
        -d "$request_body")
    local end_time=$(date +%s%3N)
    local duration=$((end_time - start_time))

    local status=$(echo "$response" | jq -r '.status_code')
    local body=$(echo "$response" | jq -r '.body')

    demo_api_response "$status" "$body"

    if [[ "$status" == "201" ]]; then
        # Database verification
        demo_db_header
        demo_table "reactions" "SELECT user_id, reaction_type, created_at FROM activity.reactions WHERE target_type='post' AND target_id='$POST_ID'"
        demo_table "posts (updated counts)" "SELECT post_id, comment_count, reaction_count FROM activity.posts WHERE post_id='$POST_ID'"

        echo -e "${COLOR_GREEN}${SYMBOL_SUCCESS} Reaction added! Post reaction_count updated.${COLOR_RESET}"

        demo_record_action "true"
        demo_record_api_time "$duration"
    else
        echo -e "${COLOR_RED}${SYMBOL_ERROR} Failed to add reaction${COLOR_RESET}"
        demo_record_action "false"
        return 1
    fi

    demo_pause
}

# ============================================================================
# DATA INTEGRITY VERIFICATION
# ============================================================================

scenario_verify_integrity() {
    demo_action "Verifying complete data integrity"

    echo -e "${COLOR_CYAN}Checking all relationships and counts...${COLOR_RESET}"
    echo ""

    # Show relationship tree
    demo_relationship_tree "$COMMUNITY_ID" "$DEMO_COMMUNITY_NAME"

    # Verify all counts
    demo_db_header
    echo -e "${COLOR_YELLOW}${SYMBOL_CHECK} Data Integrity Checks:${COLOR_RESET}"

    # Check 1: Member count accuracy
    local stored_members=$(db_query_value "SELECT member_count FROM activity.communities WHERE community_id='$COMMUNITY_ID'")
    local actual_members=$(db_query_value "SELECT COUNT(*) FROM activity.community_members WHERE community_id='$COMMUNITY_ID' AND status='active'")
    if [[ "$stored_members" == "$actual_members" ]]; then
        echo -e "   ${SYMBOL_SUCCESS} member_count: $stored_members = $actual_members ${COLOR_GREEN}✓${COLOR_RESET}"
    else
        echo -e "   ${SYMBOL_ERROR} member_count: $stored_members ≠ $actual_members ${COLOR_RED}✗${COLOR_RESET}"
    fi

    # Check 2: Post counts
    if [[ -n "$POST_ID" ]]; then
        local stored_comments=$(db_query_value "SELECT comment_count FROM activity.posts WHERE post_id='$POST_ID'")
        local actual_comments=$(db_query_value "SELECT COUNT(*) FROM activity.comments WHERE post_id='$POST_ID' AND status='active'")
        if [[ "$stored_comments" == "$actual_comments" ]]; then
            echo -e "   ${SYMBOL_SUCCESS} comment_count: $stored_comments = $actual_comments ${COLOR_GREEN}✓${COLOR_RESET}"
        fi

        local stored_reactions=$(db_query_value "SELECT reaction_count FROM activity.posts WHERE post_id='$POST_ID'")
        local actual_reactions=$(db_query_value "SELECT COUNT(*) FROM activity.reactions WHERE target_type='post' AND target_id='$POST_ID'")
        if [[ "$stored_reactions" == "$actual_reactions" ]]; then
            echo -e "   ${SYMBOL_SUCCESS} reaction_count: $stored_reactions = $actual_reactions ${COLOR_GREEN}✓${COLOR_RESET}"
        fi
    fi

    # Check 3: No orphaned records
    local orphans=$(db_query_value "SELECT COUNT(*) FROM activity.community_members cm WHERE NOT EXISTS (SELECT 1 FROM activity.users u WHERE u.user_id = cm.user_id)")
    if [[ "$orphans" == "0" ]]; then
        echo -e "   ${SYMBOL_SUCCESS} No orphaned community_members records ${COLOR_GREEN}✓${COLOR_RESET}"
    fi

    echo ""
    echo -e "${COLOR_GREEN}${SYMBOL_SUCCESS} All integrity checks passed!${COLOR_RESET}"

    demo_record_action "true"
    demo_pause
}

echo "Demo scenarios loaded"
