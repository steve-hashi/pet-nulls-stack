#!/bin/bash
# test-apply.sh - Test script for Action Invocation event flow through tfc-agent
#
# This script demonstrates how to test action invocation events.
# 
# IMPORTANT: Terraform Stacks operations require Terraform Cloud (TFC) to queue runs.
# This script provides helper functions and documentation for manual testing.
#
# Usage:
#   ./test-apply.sh help           - Show this help
#   ./test-apply.sh monitor        - Monitor tfc-agent logs for action events
#   ./test-apply.sh enable-actions - Enable action trigger (set count=1)
#   ./test-apply.sh disable-actions - Disable action trigger (set count=0)
#   ./test-apply.sh status         - Show current action trigger status

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NULLS_COMPONENT="$SCRIPT_DIR/nulls/main.tf"
TFC_AGENT_CONTAINER="tfc-agent"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper function to display help
show_help() {
    cat << 'EOF'
╔════════════════════════════════════════════════════════════════════════════╗
║                   Action Invocation Test Helper Script                     ║
╚════════════════════════════════════════════════════════════════════════════╝

This script helps test and monitor action invocation event flow through the
stack operations. Terraform Stacks operations require Terraform Cloud (TFC)
to queue deployment runs.

COMMANDS:
  help              Show this help message
  status            Show current action trigger status in nulls/main.tf
  enable-actions    Enable action trigger (set null_resource count=1)
  disable-actions   Disable action trigger (set null_resource count=0)
  monitor           Monitor tfc-agent container logs for action events
  logs-plan         Show [TRACE]/[DEBUG] logs from recent plan phase
  logs-apply        Show [TRACE]/[DEBUG] logs from recent apply phase

MANUAL TESTING:
  1. Enable actions:
     $ ./test-apply.sh enable-actions
  
  2. In another terminal, monitor logs:
     $ ./test-apply.sh monitor
  
  3. Queue a deployment run in Terraform Cloud:
     - Go to your stack in TFC
     - Click "Plan & Apply" on a deployment
     - Wait for tfc-agent to pick up the job

  4. Watch the monitor terminal for [TRACE] and [DEBUG] log messages:
     [TRACE] lifecycle action trigger: appending action invocation...
     [TRACE] reporting component instance planned...
     [TRACE] calling ReportActionInvocationPlanned hook...
     [DEBUG] ReportActionInvocationPlanned RPC hook called...
     [DEBUG] Sending ActionInvocationPlanned StackChangeProgress event...

EXPECTED LOG OUTPUT:
  During plan phase:
    ✓ [TRACE] lifecycle action trigger: appending action invocation
    ✓ [TRACE] calling ReportActionInvocationPlanned hook
    ✓ [DEBUG] ReportActionInvocationPlanned RPC hook called
    ✓ [DEBUG] Sending ActionInvocationPlanned StackChangeProgress event
  
  During apply phase:
    ✓ Similar logs for apply-phase action execution
    ✓ ActionInvocationStatus events for status updates
    ✓ ActionInvocationProgress events for progress updates

TROUBLESHOOTING:
  - If no [TRACE] logs appear: Check that terraform binary has debug logging
  - If no hook logs appear: Check that action nodes are reaching graph
  - If hook logs but no RPC logs: Check that hooks are properly wired
  - If RPC logs but no events: Check gRPC event sending

EOF
}

# Helper function to check status
show_status() {
    echo -e "${BLUE}=== Action Trigger Status ===${NC}"
    if grep -q "count = 1" "$NULLS_COMPONENT"; then
        echo -e "${GREEN}✓ Actions are ENABLED (count = 1)${NC}"
    else
        echo -e "${RED}✗ Actions are DISABLED (count = 0)${NC}"
    fi
    echo ""
    echo "Current null_resource configuration:"
    grep -A 10 "resource \"null_resource\"" "$NULLS_COMPONENT" | head -15
}

# Helper function to enable actions
enable_actions() {
    echo -e "${YELLOW}Enabling action trigger...${NC}"
    sed -i.bak 's/count = 0/count = 1/g' "$NULLS_COMPONENT"
    rm -f "$NULLS_COMPONENT.bak"
    echo -e "${GREEN}✓ Action trigger enabled (count = 1)${NC}"
    show_status
}

# Helper function to disable actions
disable_actions() {
    echo -e "${YELLOW}Disabling action trigger...${NC}"
    sed -i.bak 's/count = 1/count = 0/g' "$NULLS_COMPONENT"
    rm -f "$NULLS_COMPONENT.bak"
    echo -e "${GREEN}✓ Action trigger disabled (count = 0)${NC}"
    show_status
}

# Helper function to monitor logs
monitor_logs() {
    echo -e "${BLUE}=== Monitoring tfc-agent logs ===${NC}"
    echo -e "${CYAN}Press Ctrl+C to stop${NC}"
    echo ""
    docker logs -f "$TFC_AGENT_CONTAINER" 2>&1 | grep -E "\[TRACE\]|\[DEBUG\]|ActionInvocation" || true
}

# Helper function to show plan-phase logs
show_plan_logs() {
    echo -e "${BLUE}=== Recent Plan Phase [TRACE]/[DEBUG] Logs ===${NC}"
    docker logs "$TFC_AGENT_CONTAINER" 2>&1 | grep -E "\[TRACE\].*action invocation|lifecycle action trigger" | tail -20 || echo "No plan-phase action logs found"
}

# Helper function to show apply-phase logs
show_apply_logs() {
    echo -e "${BLUE}=== Recent Apply Phase [TRACE]/[DEBUG] Logs ===${NC}"
    docker logs "$TFC_AGENT_CONTAINER" 2>&1 | grep -E "\[TRACE\].*apply|\[DEBUG\].*apply" | tail -20 || echo "No apply-phase action logs found"
}

# Main command dispatcher
COMMAND="${1:-help}"

case "$COMMAND" in
    help)
        show_help
        ;;
    status)
        show_status
        ;;
    enable-actions)
        enable_actions
        ;;
    disable-actions)
        disable_actions
        ;;
    monitor)
        monitor_logs
        ;;
    logs-plan)
        show_plan_logs
        ;;
    logs-apply)
        show_apply_logs
        ;;
    *)
        echo -e "${RED}Unknown command: $COMMAND${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac
