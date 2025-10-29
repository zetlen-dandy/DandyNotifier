# DandyNotifier

A persistent macOS notification server that displays rich notifications with working action buttons, even when called from background processes.

## Problem

Tools like `terminal-notifier` and `alerter` have issues on modern macOS (Sequoia/Tahoe) when called from background scripts (like git hooks):
- Action buttons don't work reliably
- Notifications may not appear
- Permission issues in background contexts

## Solution

DandyNotifier runs as a persistent menu bar agent with proper notification permissions. Background scripts make HTTP requests to the server, which handles notifications in a privileged context where action buttons work correctly.

## Features

- ✅ Persistent background server (survives script termination)
- ✅ Working action buttons from background processes
- ✅ Rich notifications (title, subtitle, message, sound, icon)
- ✅ Notification grouping
- ✅ Custom sounds and icons
- ✅ Authenticated HTTP API
- ✅ Simple CLI tool
- ✅ Auto-starts on login (via LaunchAgent)

## Installation

### 1. Build the App

```bash
cd /path/to/DandyNotifier
xcodebuild -project DandyNotifier.xcodeproj -scheme DandyNotifier -configuration Release
```

### 2. Install the App

```bash
cp -r build/Release/DandyNotifier.app /Applications/
```

### 3. Install CLI Tool

```bash
chmod +x CLI/dandy-notify
sudo cp CLI/dandy-notify /usr/local/bin/
```

### 4. Setup Auto-Start (Optional)

The LaunchAgent will start the app on login but **won't auto-restart** if you quit it.

```bash
cp LaunchAgent/com.orthly.DandyNotifier.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.orthly.DandyNotifier.plist
```

**Note:** The app can be quit normally via the menu bar "Quit" option and will stay quit until you log in again or manually restart it. If you want the app to auto-restart even after quitting, edit the plist and add:
```xml
<key>KeepAlive</key>
<true/>
```

## Usage

### Start the Server

Launch `DandyNotifier.app` from Applications. It will:
1. Request notification permissions (if needed)
2. Start HTTP server on port 8889
3. Create auth token in `~/.dandy-notifier-token`
4. Show menu bar icon (bell)

### Using the CLI

#### Simple notification:
```bash
dandy-notify -t "Build Complete" -m "Your project compiled successfully"
```

#### With action button:
```bash
dandy-notify \
  -t "Test Failed" \
  -m "Click to view logs" \
  -o "file:///tmp/test.log"
```

#### Git hook example:
```bash
#!/bin/bash
# .git/hooks/post-checkout

LOG_FILE="/tmp/post-checkout.log"
date > "$LOG_FILE"

if ! ./run-tests.sh >> "$LOG_FILE" 2>&1; then
    dandy-notify \
        -t "Repository" \
        -s "post-checkout hook" \
        -m "Tests failed. Click to view logs." \
        -o "file://$LOG_FILE" \
        -g "git-hooks" \
        --sound "/System/Library/Sounds/Basso.aiff"
fi
```

### Using the HTTP API

#### Health check:
```bash
curl http://localhost:8889/health
```

#### Send notification:
```bash
TOKEN=$(cat ~/.dandy-notifier-token)

curl -X POST http://localhost:8889/notify \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "notification": {
      "title": "Hello",
      "message": "World",
      "subtitle": "Test",
      "group": "myapp",
      "sound": "/System/Library/Sounds/Ping.aiff",
      "action": {
        "id": "open_logs",
        "label": "Show Logs",
        "type": "open",
        "location": "file:///tmp/logs.txt"
      }
    }
  }'
```

## API Reference

### POST /notify

**Headers:**
- `Content-Type: application/json`
- `Authorization: Bearer <token>`

**Body:**
```json
{
  "notification": {
    "title": "string (required)",
    "message": "string (required)",
    "subtitle": "string (optional)",
    "group": "string (optional)",
    "sound": "string (optional, path to .aiff file)",
    "icon": "string (optional, path to image)",
    "action": {
      "id": "string (required)",
      "label": "string (required)",
      "type": "string (currently only 'open')",
      "location": "string (required, file:// URL or path)"
    }
  }
}
```

**Response:**
- `200 OK` - Notification sent
- `400 Bad Request` - Invalid JSON
- `401 Unauthorized` - Invalid/missing token
- `500 Internal Server Error` - Server error

### GET /health

Returns `200 OK` if server is running.

## Architecture

```
┌─────────────────────────────────────────┐
│  DandyNotifier.app (Menu Bar Agent)     │
│  ┌─────────────────────────────────┐   │
│  │  HTTP Server (Port 8889)        │   │
│  │  - POST /notify                 │   │
│  │  - GET /health                  │   │
│  └─────────────────────────────────┘   │
│  ┌─────────────────────────────────┐   │
│  │  NotificationManager            │   │
│  │  - UNUserNotificationCenter     │   │
│  │  - Action button handling       │   │
│  └─────────────────────────────────┘   │
│  ┌─────────────────────────────────┐   │
│  │  Menu Bar UI                    │   │
│  │  - Bell icon                    │   │
│  │  - Quit option                  │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
           ▲
           │ HTTP POST (localhost only)
           │
┌──────────┴──────────┐
│  CLI Tool           │
│  dandy-notify       │
│  (or direct curl)   │
└─────────────────────┘
```

## Security

- Server only accepts connections from localhost
- Authentication token required for all requests
- Token stored with restrictive permissions (0600)
- Non-sandboxed app (required for arbitrary file access)

## Troubleshooting

### Notifications not appearing
1. Check System Settings > Notifications > DandyNotifier
2. Ensure "Allow Notifications" is enabled
3. Set alert style to "Alerts" (not "Banners")

### Action buttons not working
- Make sure you're using `file://` URLs for local files
- Check that DandyNotifier.app is running
- Verify permissions in System Settings

### Server not starting
- Check if port 8889 is already in use: `lsof -i :8889`
- Look at Console.app for DandyNotifier logs

### Token not found
- Launch DandyNotifier.app manually once
- Token is created at `~/.dandy-notifier-token`

### Can't quit the app
If the app won't quit or keeps restarting:
1. Check if LaunchAgent has `KeepAlive = true` (it will auto-restart)
2. Unload the LaunchAgent: `launchctl unload ~/Library/LaunchAgents/com.orthly.DandyNotifier.plist`
3. Then quit the app from the menu bar
4. By default, the LaunchAgent does NOT use KeepAlive, so quit should work normally

### App is sandboxed / Permission errors
- Ensure `ENABLE_APP_SANDBOX = NO` in Xcode build settings
- Check entitlements file has `<key>com.apple.security.app-sandbox</key><false/>`
- Rebuild after changing these settings

## Comparison with terminal-notifier

| Feature | terminal-notifier | DandyNotifier |
|---------|------------------|---------------|
| Background process support | ❌ Actions broken | ✅ Works perfectly |
| Sequoia compatibility | ⚠️ Limited | ✅ Full |
| Action buttons | ❌ From background | ✅ Always works |
| Persistent server | ❌ | ✅ |
| HTTP API | ❌ | ✅ |
| Custom sounds | ✅ | ✅ |
| Custom icons | ✅ | ✅ |
| Grouping | ✅ | ✅ |

## License

MIT

## Author

Created by James Zetlen for Dandy


