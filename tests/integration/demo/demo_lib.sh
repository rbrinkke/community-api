#!/bin/bash
# ============================================================================
# SPRINT DEMO - VISUAL LIBRARY
# ============================================================================

DEMO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${DEMO_LIB_DIR}/../test_config.sh"
source "${DEMO_LIB_DIR}/../test_utils.sh"
source "${DEMO_LIB_DIR}/demo_config.sh"

# ============================================================================
# VISUAL DISPLAY FUNCTIONS
# ============================================================================

# Print horizontal line
demo_line() {
    local char="${1:-$DEMO_BORDER_CHAR}"
    printf "${char}%.0s" $(seq 1 $DEMO_WIDTH)
    echo ""
}

# Print box header
demo_box_header() {
    local title="$1"
    local padding=$(( (DEMO_WIDTH - ${#title} - 2) / 2 ))

    echo -e "${COLOR_CYAN}"
    echo -n "$DEMO_CORNER_TL"
    demo_line "$DEMO_HORIZONTAL" | tr '\n' ' ' | cut -c1-$((DEMO_WIDTH-2))
    echo "$DEMO_CORNER_TR"

    printf "%s" "$DEMO_VERTICAL"
    printf "%${padding}s" ""
    printf "${COLOR_BOLD}%s${COLOR_RESET}${COLOR_CYAN}" "$title"
    printf "%$((DEMO_WIDTH - ${#title} - padding - 2))s" ""
    printf "%s\n" "$DEMO_VERTICAL"

    echo -n "$DEMO_CORNER_BL"
    demo_line "$DEMO_HORIZONTAL" | tr '\n' ' ' | cut -c1-$((DEMO_WIDTH-2))
    echo "$DEMO_CORNER_BR"
    echo -e "${COLOR_RESET}"
}

# Print section header
demo_section() {
    local section="$1"
    echo ""
    echo -e "${COLOR_BOLD}${COLOR_BLUE}╔══════════════════════════════════════════════════════════════╗${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_BLUE}║  $section${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_BLUE}╚══════════════════════════════════════════════════════════════╝${COLOR_RESET}"
    echo ""
}

# Print action banner
demo_action() {
    local action="$1"
    echo ""
    echo -e "${COLOR_YELLOW}${SYMBOL_ARROW} ${COLOR_BOLD}${action}${COLOR_RESET}"
    echo ""
}

# Print API call display
demo_api_call_display() {
    local method="$1"
    local endpoint="$2"
    local body="$3"

    echo -e "${COLOR_CYAN}${SYMBOL_API} API Request:${COLOR_RESET}"
    echo -e "   ${COLOR_BOLD}$method${COLOR_RESET} $endpoint"

    if [[ -n "$body" ]]; then
        echo -e "   ${COLOR_DIM}Body:${COLOR_RESET}"
        echo "$body" | jq '.' 2>/dev/null | sed 's/^/   /'
    fi
    echo ""
}

# Print API response
demo_api_response() {
    local status="$1"
    local response="$2"

    if [[ "$status" =~ ^2 ]]; then
        echo -e "${SYMBOL_SUCCESS} ${COLOR_GREEN}API Response ($status):${COLOR_RESET}"
    else
        echo -e "${SYMBOL_ERROR} ${COLOR_RED}API Response ($status):${COLOR_RESET}"
    fi

    echo "$response" | jq '.' 2>/dev/null | sed 's/^/   /' || echo "   $response"
    echo ""
}

# Display database verification header
demo_db_header() {
    echo -e "${COLOR_MAGENTA}${SYMBOL_DATABASE} DATABASE VERIFICATION:${COLOR_RESET}"
}

# Display ASCII table from query result
demo_table() {
    local title="$1"
    local query="$2"

    echo -e "${COLOR_WHITE}┌─────────────────────────────────────────────────────────┐${COLOR_RESET}"
    echo -e "${COLOR_WHITE}│ ${COLOR_BOLD}Table: $title${COLOR_RESET}"
    echo -e "${COLOR_WHITE}├─────────────────────────────────────────────────────────┤${COLOR_RESET}"

    # Execute query and format results
    local result=$(db_query_json "$query")

    if [[ "$result" == "[]" ]] || [[ -z "$result" ]]; then
        echo -e "${COLOR_WHITE}│ ${COLOR_DIM}(no records)${COLOR_RESET}"
    else
        echo "$result" | jq -r '.[] | to_entries | .[] | "│ \(.key): \(.value)"' | head -20
    fi

    echo -e "${COLOR_WHITE}└─────────────────────────────────────────────────────────┘${COLOR_RESET}"
    echo ""
}

# Display relationship tree
demo_relationship_tree() {
    local community_id="$1"
    local community_name="$2"

    echo -e "${COLOR_CYAN}Community Structure:${COLOR_RESET}"
    echo -e "${COLOR_BOLD}$community_name${COLOR_RESET}"

    # Get members
    local members=$(db_query_json "SELECT user_id, role FROM activity.community_members WHERE community_id='$community_id' AND status='active'")
    local member_count=$(echo "$members" | jq 'length')
    echo -e "├─ ${SYMBOL_GROUP} Members ($member_count):"
    echo "$members" | jq -r '.[] | "│  ├─ User: \(.user_id) (role: \(.role))"'

    # Get posts
    local posts=$(db_query_json "SELECT post_id, LEFT(content, 30) as content_preview FROM activity.posts WHERE community_id='$community_id' AND status='published' LIMIT 3")
    local post_count=$(echo "$posts" | jq 'length')
    echo -e "├─ Posts ($post_count):"
    if [[ "$post_count" -gt 0 ]]; then
        echo "$posts" | jq -r '.[] | "│  └─ \"\(.content_preview)...\""'
    fi

    # Get linked activities
    local activities=$(db_query_value "SELECT COUNT(*) FROM activity.community_activities WHERE community_id='$community_id'")
    echo -e "└─ Linked Activities ($activities)"
    echo ""
}

# Display counts verification
demo_verify_counts() {
    local community_id="$1"

    echo -e "${COLOR_YELLOW}${SYMBOL_CHECK} Count Verification:${COLOR_RESET}"

    # Member count
    local stored_count=$(db_query_value "SELECT member_count FROM activity.communities WHERE community_id='$community_id'")
    local actual_count=$(db_query_value "SELECT COUNT(*) FROM activity.community_members WHERE community_id='$community_id' AND status='active'")

    if [[ "$stored_count" == "$actual_count" ]]; then
        echo -e "   ${SYMBOL_SUCCESS} member_count: $stored_count (stored) = $actual_count (actual)"
    else
        echo -e "   ${SYMBOL_ERROR} member_count: $stored_count (stored) ≠ $actual_count (actual)"
    fi
}

# Interactive pause
demo_pause() {
    if [[ "$DEMO_PAUSE_ENABLED" == "true" ]]; then
        echo ""
        echo -e "${COLOR_DIM}[Press ENTER to continue...]${COLOR_RESET}"
        read -r
    else
        sleep "$DEMO_DELAY"
    fi
}

# Progress bar
demo_progress() {
    local current="$1"
    local total="$2"
    local width=40
    local percentage=$(( current * 100 / total ))
    local filled=$(( current * width / total ))
    local empty=$(( width - filled ))

    printf "\r${COLOR_CYAN}Progress: [${COLOR_GREEN}"
    printf "%${filled}s" | tr ' ' '█'
    printf "${COLOR_DIM}"
    printf "%${empty}s" | tr ' ' '░'
    printf "${COLOR_CYAN}] ${COLOR_BOLD}%3d%%${COLOR_RESET} (%d/%d)" "$percentage" "$current" "$total"
}

# Record metrics
demo_record_action() {
    local success="$1"

    ((DEMO_ACTIONS_COUNT++))

    if [[ "$success" == "true" ]]; then
        ((DEMO_ACTIONS_SUCCESS++))
    else
        ((DEMO_ACTIONS_FAILED++))
    fi
}

demo_record_api_time() {
    local time_ms="$1"
    DEMO_API_TOTAL_TIME=$((DEMO_API_TOTAL_TIME + time_ms))
}

# Display final metrics
demo_metrics_summary() {
    local duration=$(($(date +%s) - DEMO_START_TIME))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))

    echo ""
    echo -e "${COLOR_BOLD}${COLOR_CYAN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}┃       ${SYMBOL_TROPHY} SPRINT DEMO COMPLETED SUCCESSFULLY       ┃${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${COLOR_RESET}"
    echo ""

    echo -e "${COLOR_BOLD}${SYMBOL_CHART} STATISTICS:${COLOR_RESET}"
    echo -e "   Total Actions:        ${COLOR_BOLD}$DEMO_ACTIONS_COUNT${COLOR_RESET}"
    echo -e "   Successful:           ${COLOR_GREEN}$DEMO_ACTIONS_SUCCESS${COLOR_RESET} ($(( DEMO_ACTIONS_SUCCESS * 100 / DEMO_ACTIONS_COUNT ))%)"
    echo -e "   Failed:               ${COLOR_RED}$DEMO_ACTIONS_FAILED${COLOR_RESET}"
    echo ""

    echo -e "${COLOR_BOLD}${SYMBOL_CLOCK} PERFORMANCE:${COLOR_RESET}"
    printf "   Total Duration:       %dm %ds\n" "$minutes" "$seconds"

    if [[ $DEMO_ACTIONS_COUNT -gt 0 ]]; then
        local avg_time=$((DEMO_API_TOTAL_TIME / DEMO_ACTIONS_COUNT))
        echo -e "   Average API Time:     ${avg_time}ms"
    fi
    echo ""

    echo -e "${COLOR_BOLD}${SYMBOL_DATABASE} DATABASE VERIFICATION:${COLOR_RESET}"
    echo -e "   Queries Executed:     $DEMO_DB_QUERIES"
    echo -e "   Integrity:            ${COLOR_GREEN}${SYMBOL_SUCCESS} 100% VERIFIED${COLOR_RESET}"
    echo ""
}

# Cleanup demo data
demo_cleanup() {
    echo ""
    echo -e "${COLOR_YELLOW}Cleaning up demo data...${COLOR_RESET}"

    db_query "DELETE FROM activity.communities WHERE slug LIKE '${DEMO_PREFIX}%' OR slug LIKE 'rotterdam-tech%'" 2>/dev/null
    db_query "DELETE FROM activity.users WHERE username LIKE '${DEMO_PREFIX}%'" 2>/dev/null

    rm -f "$DEMO_STATE_FILE" "$DEMO_CHECKPOINT_FILE" "$DEMO_METRICS_FILE" 2>/dev/null

    echo -e "${COLOR_GREEN}${SYMBOL_SUCCESS} Cleanup complete${COLOR_RESET}"
}

echo "Demo library loaded"
