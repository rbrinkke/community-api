#!/bin/bash
# ============================================================================
# SPRINT DEMO - CONFIGURATION
# ============================================================================

# Demo personas
export DEMO_ALICE_USERNAME="demo_alice"
export DEMO_ALICE_EMAIL="alice@rotterdamtech.nl"
export DEMO_ALICE_NAME="Alice van Berg"

export DEMO_BOB_USERNAME="demo_bob"
export DEMO_BOB_EMAIL="bob@techdev.nl"
export DEMO_BOB_NAME="Bob de Vries"

export DEMO_CAROL_USERNAME="demo_carol"
export DEMO_CAROL_EMAIL="carol@innovation.nl"
export DEMO_CAROL_NAME="Carol Janssen"

# Demo data identifiers
export DEMO_PREFIX="demo_"
export DEMO_COMMUNITY_NAME="Rotterdam Tech Meetup"
export DEMO_COMMUNITY_SLUG="rotterdam-tech-$(date +%s)"
export DEMO_ACTIVITY_NAME="Tech Networking Event - January 2025"

# Demo settings
export DEMO_PAUSE_ENABLED=true
export DEMO_SHOW_SQL=false
export DEMO_VERBOSE=false
export DEMO_DELAY=1  # seconds between visual elements

# Visual settings
export DEMO_WIDTH=80
export DEMO_BORDER_CHAR="━"
export DEMO_CORNER_TL="┏"
export DEMO_CORNER_TR="┓"
export DEMO_CORNER_BL="┗"
export DEMO_CORNER_BR="┛"
export DEMO_VERTICAL="┃"
export DEMO_HORIZONTAL="━"

# Metrics tracking
export DEMO_START_TIME=0
export DEMO_ACTIONS_COUNT=0
export DEMO_ACTIONS_SUCCESS=0
export DEMO_ACTIONS_FAILED=0
export DEMO_API_TOTAL_TIME=0
export DEMO_DB_QUERIES=0

# State files
export DEMO_STATE_FILE="/tmp/demo_state_$$"
export DEMO_CHECKPOINT_FILE="/tmp/demo_checkpoint_$$"
export DEMO_METRICS_FILE="/tmp/demo_metrics_$$"

# Color codes (reuse from test_config if available)
if [[ -z "$COLOR_RED" ]]; then
    export COLOR_RED='\033[0;31m'
    export COLOR_GREEN='\033[0;32m'
    export COLOR_YELLOW='\033[1;33m'
    export COLOR_BLUE='\033[0;34m'
    export COLOR_MAGENTA='\033[0;35m'
    export COLOR_CYAN='\033[0;36m'
    export COLOR_WHITE='\033[1;37m'
    export COLOR_BOLD='\033[1m'
    export COLOR_DIM='\033[2m'
    export COLOR_RESET='\033[0m'
fi

# Symbols
export SYMBOL_CHECK="✓"
export SYMBOL_CROSS="✗"
export SYMBOL_ARROW="→"
export SYMBOL_BULLET="•"
export SYMBOL_ROCKET="🚀"
export SYMBOL_DATABASE="💾"
export SYMBOL_API="📤"
export SYMBOL_SUCCESS="✅"
export SYMBOL_ERROR="❌"
export SYMBOL_WARNING="⚠️"
export SYMBOL_INFO="ℹ️"
export SYMBOL_TROPHY="🏆"
export SYMBOL_CHART="📊"
export SYMBOL_CLOCK="⏱️"
export SYMBOL_PERSON="👤"
export SYMBOL_GROUP="👥"

echo "Demo configuration loaded"
