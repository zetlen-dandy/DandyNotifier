#!/bin/bash
# Example: Long-running background task with notifications

set -e

TASK_NAME="Data Processing"
LOG_FILE="/tmp/background-task-$(date +%s).log"

# Notify start
dandy-notify \
    -t "$TASK_NAME" \
    -m "Starting background task..." \
    -g "background-tasks"

# Simulate long-running task
{
    echo "=== Background Task Started at $(date) ==="
    echo ""
    
    for i in {1..5}; do
        echo "Processing batch $i/5..."
        sleep 2
        
        # Simulate occasional errors
        if [[ $i -eq 3 ]]; then
            echo "Warning: Retry required for batch $i"
        fi
    done
    
    echo ""
    echo "=== Task Completed at $(date) ==="
} > "$LOG_FILE" 2>&1

# Notify completion with action to view logs
dandy-notify \
    -t "$TASK_NAME" \
    -m "Background task completed successfully" \
    -o "file://$LOG_FILE" \
    -g "background-tasks" \
    --sound "/System/Library/Sounds/Glass.aiff"

echo "✓ Task complete. Check notifications!"


