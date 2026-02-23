# Testing Action Invocation Event Flow

This document explains how to test the action invocation event flow through the Terraform Stacks infrastructure.

## Overview

The pet-nulls-stack is configured to test action invocation events with a `bufo_print.success` action triggered after creating a `null_resource`. This tests the complete event flow:

1. **Plan Phase**: Terraform Core evaluates the `action_trigger` lifecycle and queues action invocations
2. **Reporting**: The planning stage reports action invocations through hooks
3. **RPC Layer**: Hooks are converted to gRPC `StackChangeProgress` events
4. **tfc-agent**: Events are received and logged

## Test Script Usage

A helper script `test-apply.sh` is provided to manage the test configuration:

### Commands

```bash
./test-apply.sh help              # Show this help
./test-apply.sh status            # Show current action trigger status
./test-apply.sh enable-actions    # Enable actions (count=1)
./test-apply.sh disable-actions   # Disable actions (count=0)
./test-apply.sh monitor           # Monitor tfc-agent logs
./test-apply.sh logs-plan         # Show plan-phase action logs
./test-apply.sh logs-apply        # Show apply-phase action logs
```

## Manual Testing Workflow

### Step 1: Enable Actions

This modifies `nulls/main.tf` to set `count = 1` on the null_resource, which will trigger the action:

```bash
cd /Users/roniecericardo/work/stacks/pet-nulls-stack
./test-apply.sh enable-actions
```

### Step 2: Monitor Logs

In a new terminal, monitor the tfc-agent container for debug logs:

```bash
./test-apply.sh monitor
```

This will show [TRACE] and [DEBUG] logs as they appear.

### Step 3: Queue a Deployment Run

In Terraform Cloud:
1. Navigate to your stack
2. Select a deployment (e.g., "simple")
3. Click "Plan & Apply"
4. The tfc-agent will pick up the job

### Step 4: Observe Debug Output

Watch the monitor terminal for expected log messages in this order:

**Plan Phase:**
```
[TRACE] lifecycle action trigger: appending action invocation {action_addr} with trigger event {event_type}
[TRACE] reporting component instance planned: component=nulls, action invocations in plan=1
[TRACE] calling ReportActionInvocationPlanned hook for action {action_addr}
[DEBUG] ReportActionInvocationPlanned RPC hook called for action {action_addr}
[DEBUG] Sending ActionInvocationPlanned StackChangeProgress event for {action_addr}
```

**Approval:**
- User approves pending plan run in TFC

**Apply Phase:**
```
[DEBUG] ReportActionInvocationStatus RPC hook called...
[DEBUG] Sending ActionInvocationStatus StackChangeProgress event...
[DEBUG] ReportActionInvocationProgress RPC hook called...
[DEBUG] Sending ActionInvocationProgress StackChangeProgress event...
```

### Step 5: Restore Configuration

After testing, disable actions to restore the configuration:

```bash
./test-apply.sh disable-actions
```

## Expected Output Format

### Debug Log Example

```json
{"@level":"debug","@message":"ReportActionInvocationPlanned RPC hook called for action stack.nulls.action.bufo_print.success","@module":"rpcapi.stacks"}
{"@level":"debug","@message":"Sending ActionInvocationPlanned StackChangeProgress event for stack.nulls.action.bufo_print.success","@module":"rpcapi.stacks"}
```

### Check Recent Logs

```bash
# Show plan-phase action invocation logs
./test-apply.sh logs-plan

# Show apply-phase action invocation logs  
./test-apply.sh logs-apply
```

## Troubleshooting

### No [TRACE] logs appear
- Verify terraform binary was rebuilt with logging: `ls -lh /Users/roniecericardo/work/hashicorp/terraform/terraform`
- Check that tfc-agent is using the correct binary
- Verify `node_action_trigger_instance_plan.go` has the log statement at line 198

### No hook logs appear
- Action invocations may not be reaching the graph
- Check that `transform_action_invoke_apply.go` has the fix (removed `len(t.ActionTargets)==0` check)
- Verify action nodes are being created during planning

### Hook logs but no RPC logs
- Check that hooks are properly wired in `rpcapi/stacks.go` line 1209
- Verify `ReportActionInvocationPlanned` handler is present

### RPC logs but no events in stream
- Check gRPC connection is active
- Verify `StackChangeProgress` event is being marshaled correctly
- Check tfc-agent is receiving events from the RPC stream

## Code Locations

- **Plan Phase Action Append**: [internal/terraform/node_action_trigger_instance_plan.go](internal/terraform/node_action_trigger_instance_plan.go) line 198
- **Component Reporting**: [internal/stacks/stackruntime/internal/stackeval/planning.go](internal/stacks/stackruntime/internal/stackeval/planning.go) line 110
- **RPC Hook Handler**: [internal/rpcapi/stacks.go](internal/rpcapi/stacks.go) line 1209
- **Apply Transformer**: [internal/terraform/transform_action_invoke_apply.go](internal/terraform/transform_action_invoke_apply.go) line 22

## Test Configuration

The test stack uses:
- **Component**: `nulls` (with `null_resource` and `action.bufo_print`)
- **Resource**: `null_resource.this` (count = 0 by default)
- **Trigger**: `action_trigger` on `after_create` and `after_update` events
- **Action**: `bufo_print.success` from austinvalle/bufo provider

When enabled (count = 1), this creates a null_resource that triggers the action.

## Commits Related to Action Invocation Event Flow

- **46ff0bf203**: "Fix: Include action invocations in apply graph" - Removed incorrect `len(t.ActionTargets)==0` check
- **233ab34f3c**: "Add debug logging for action invocation event flow" - Added logging at plan append, hook reporting, and RPC handler

## References

- [Terraform Stacks Documentation](https://www.terraform.io/docs/cloud/stacks)
- [Action Invocation Protocol Buffers](../terraform/internal/rpcapi/terraform1/stacks/stacks.proto)
- [tfc-agent Stacks Streaming](../tfc-agent/core/components/stacks/streaming.go)
