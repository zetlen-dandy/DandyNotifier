#!/bin/bash
# Test script for DandyNotifier

set -e

TOKEN_FILE="$HOME/.dandy-notifier-token"
SERVER_URL="http://localhost:8889"

echo "🧪 Testing DandyNotifier..."

# Check if token exists
if [[ ! -f "$TOKEN_FILE" ]]; then
    echo "❌ Token file not found at $TOKEN_FILE"
    echo "   Make sure DandyNotifier.app is running"
    exit 1
fi

TOKEN=$(cat "$TOKEN_FILE")
echo "✓ Token found"

# Test health endpoint
echo -n "Testing /health endpoint... "
if curl -s -f "$SERVER_URL/health" > /dev/null; then
    echo "✓"
else
    echo "❌"
    echo "   Is DandyNotifier.app running?"
    exit 1
fi

# Test simple notification
echo -n "Testing simple notification... "
RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null \
    -X POST "$SERVER_URL/notify" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{
        "notification": {
            "title": "Test Notification",
            "message": "This is a test from DandyNotifier!",
            "group": "simple-test"
        }
    }')

if [[ "$RESPONSE" == "200" ]]; then
    echo "✓"
else
    echo "❌ (HTTP $RESPONSE)"
    exit 1
fi
sleep 0.2

# Test notification with subtitle
echo -n "Testing notification with subtitle... "
RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null \
    -X POST "$SERVER_URL/notify" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{
        "notification": {
            "title": "Test Title",
            "subtitle": "Test Subtitle",
            "message": "This notification has a subtitle",
            "group": "subtitle-test"
        }
    }')

if [[ "$RESPONSE" == "200" ]]; then
    echo "✓"
else
    echo "❌ (HTTP $RESPONSE)"
    exit 1
fi
sleep 0.2

# Test notification with action button
echo -n "Testing notification with action button... "
TEST_LOG="/tmp/dandy-test-$(date +%s).txt"
echo "This is a test log file" > "$TEST_LOG"

RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null \
    -X POST "$SERVER_URL/notify" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d "{
        \"notification\": {
            \"title\": \"Action Button Test\",
            \"message\": \"Click the button to open the log file\",
            \"group\": \"action-test\",
            \"action\": {
                \"id\": \"open_log\",
                \"label\": \"Show Log\",
                \"type\": \"open\",
                \"location\": \"file://$TEST_LOG\"
            }
        }
    }")

if [[ "$RESPONSE" == "200" ]]; then
    echo "✓"
    echo "   📝 Test log created at: $TEST_LOG"
    echo "   👆 Click the notification action button to open it"
else
    echo "❌ (HTTP $RESPONSE)"
    exit 1
fi
sleep 0.2

# Test notification with grouping
echo -n "Testing grouped notifications... "
for i in 1 2 3; do
    curl -s -X POST "$SERVER_URL/notify" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d "{
            \"notification\": {
                \"title\": \"Grouped Test $i\",
                \"message\": \"Message $i of 3\",
                \"group\": \"test-group-$i\"
            }
        }" > /dev/null
    sleep 0.2  # Small delay to ensure all appear
done
echo "✓ (sent 3 notifications with unique groups)"

# Test notification with sound
echo -n "Testing notification with sound... "
RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null \
    -X POST "$SERVER_URL/notify" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{
        "notification": {
            "title": "Sound Test",
            "message": "This notification should play a sound",
            "sound": "/System/Library/Sounds/Ping.aiff",
            "group": "sound-test"
        }
    }')

if [[ "$RESPONSE" == "200" ]]; then
    echo "✓"
else
    echo "❌ (HTTP $RESPONSE)"
    exit 1
fi
sleep 0.2

echo ""
echo "✅ All tests passed!"
echo ""
echo "Next steps:"
echo "  1. Check your notifications - you should see several test notifications"
echo "  2. Try clicking the action button on the 'Action Button Test' notification"
echo "  3. Install the CLI: sudo cp CLI/dandy-notify /usr/local/bin/"
echo "  4. Test the CLI: dandy-notify -t 'CLI Test' -m 'Testing the CLI tool'"


