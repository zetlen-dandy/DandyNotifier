# DandyNotifier Development Context

## Project Overview

DandyNotifier is a macOS menubar application that provides a local HTTP server for sending rich notifications. It was created to solve a specific problem: macOS notification action buttons don't work reliably from background processes like Git hooks.

### Why This Exists

**The Problem:**
- Git hooks run as background processes
- `NSWorkspace.open()` fails silently from background contexts
- Notifications need to persist action data even if the app restarts

**The Solution:**
- Long-running menubar app (GUI context) that can reliably handle actions
- HTTP server accepts notification requests from any process
- Action data stored in notification `userInfo` (survives app restarts)
- Native Swift CLI for sending notifications

## Architecture

### Components

1. **DandyNotifier.app** - Main menubar application
   - Runs as LaunchAgent (auto-starts on login)
   - HTTP server on port 8889
   - Handles macOS UserNotifications framework
   
2. **dandy-notify** - Native Swift CLI
   - Lives in `/usr/local/bin/` and app bundle
   - Communicates with server via HTTP
   - Uses curl internally (URLSession had connection reuse bugs)

3. **LaunchAgent** - `com.orthly.DandyNotifier.plist`
   - Auto-starts server on login
   - Redirects stdout to `/tmp/DandyNotifier.log`
   - Redirects stderr to `/tmp/DandyNotifier.error.log`

### Key Files

- `DandyNotifier/NotificationServer.swift` - HTTP server (manual implementation, no frameworks)
- `DandyNotifier/NotificationManager.swift` - UserNotifications logic
- `DandyNotifier/DandyNotifierApp.swift` - Menubar app and entry point
- `CLI.swift` - Native Swift CLI client
- `Makefile` - Build and installation automation

## Features

### Notification Options

| Flag | Description | Example |
|------|-------------|---------|
| `-t, --title` | Title (required) | "Build Complete" |
| `-s, --subtitle` | Subtitle | "post-commit hook" |
| `-m, --message` | Message (required) | "All tests passed" |
| `-g, --group` | Group identifier | "git-hooks" |
| `--sound` | Custom sound path | "/System/Library/Sounds/Basso.aiff" |
| `-i, --interruption` | Level (passive\|active\|timeSensitive\|critical) | "timeSensitive" |
| `-a, --attachment` | Image/video/audio (path or URL) | "/tmp/screenshot.png" |
| `-o, --open` | Open location when clicked | "file:///tmp/log.txt" |
| `-e, --execute` | Execute shell command when clicked | "open https://example.com" |
| `-d, --debug` | Print JSON payload to stderr | N/A |

### Interruption Levels

- **passive** - Minimal distraction, stays in Notification Center
- **active** - Normal priority (default)
- **timeSensitive** - Breaks through Focus modes
- **critical** - Highest priority, always shows with sound

### Action Buttons

Supports up to 4 action buttons per notification. Two types:

1. **Open Type:**
```json
{
  "id": "open_action",
  "label": "Open",
  "type": "open",
  "location": "/path/or/url"
}
```

2. **Execute Type:**
```json
{
  "id": "exec_action",
  "label": "Execute",
  "type": "exec",
  "exec": "/bin/bash",
  "args": ["-c", "command here"]
}
```

### Attachments

Supports both local files and remote URLs:
- **Local**: `-a "/path/to/image.png"`
- **Remote**: `-a "https://example.com/logo.png"`

Media types: images (png, jpg, gif), videos (mp4, mov), audio (mp3, aiff, wav)

## Development Workflow

### Build and Install

```bash
make install
```

This:
1. Updates version from `git describe --tags --always`
2. Builds Xcode project
3. Compiles Swift CLI
4. Installs to `/Applications/DandyNotifier.app`
5. Installs CLI to `/usr/local/bin/dandy-notify`
6. Loads LaunchAgent

### Testing

```bash
# Simple test
dandy-notify -t "Test" -m "Hello"

# Full test with all features
dandy-notify \
  -t "Full Test" \
  -s "Subtitle here" \
  -m "Message text" \
  -i timeSensitive \
  -a "/path/to/image.png" \
  -e "echo 'clicked' >> /tmp/test.log"
```

### Logging

- **Normal logs**: `tail -f /tmp/DandyNotifier.log`
- **Error logs**: `tail -f /tmp/DandyNotifier.error.log`

**Important:** The app uses `FileHandle.standardOutput.write()` instead of `print()` because it's a GUI app and `print()` doesn't write to stdout in GUI contexts.

### Version Management

Version is auto-updated during build:
- Makefile runs `git describe --tags --always` before xcodebuild
- Updates `NotificationServer.swift` with current commit hash
- Version accessible via `/version` endpoint
- Displayed in menubar: "DandyNotifier v{hash}"

## Critical Implementation Details

### HTTP Server

**Manual implementation** (no framework) because:
- Only 3 endpoints needed (/health, /version, /notify)
- Zero dependencies
- Lightweight for menubar app

**Body Parsing Bug (FIXED):**
Early versions converted HTTP body to string and back, which corrupted binary JSON data. Fixed by extracting body as raw `Data` after finding `\r\n\r\n` separator.

```swift
let headerSeparator = Data([13, 10, 13, 10]) // \r\n\r\n
let bodyData = data.subdata(in: separatorRange.upperBound..<data.count)
```

### CLI Implementation

**Uses curl instead of URLSession:**
URLSession had connection reuse issues causing subsequent requests to send empty bodies. Curl is more reliable for simple HTTP POST requests.

```swift
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
process.arguments = ["-s", "-X", "POST", "-H", "Content-Type: application/json", ...]
```

### Action Execution

Actions execute via `Process()` with proper command separation:

```swift
let task = Process()
task.launchPath = command  // e.g., "/bin/bash"
task.arguments = args      // e.g., ["-c", "open file.txt"]
```

**Why not `NSWorkspace.open()`?**
Fails silently from background contexts. `/usr/bin/open` via `Process()` is more reliable.

### Logging in GUI Apps

**Critical Insight:**
`print()` doesn't write to stdout in macOS GUI apps. Must use:

```swift
FileHandle.standardOutput.write(data)  // stdout
FileHandle.standardError.write(data)   // stderr
```

This allows LaunchAgent's stdout/stderr redirection to work properly.

## Common Issues & Solutions

### "Server returned HTTP 400"

**Check:**
1. Server logs: `tail /tmp/DandyNotifier.error.log`
2. JSON debug: `dandy-notify -d ...`
3. Version mismatch: `curl http://localhost:8889/version`

### No Logs Appearing

**Cause:** Using `print()` instead of `FileHandle.standardOutput`

**Fix:** All logging must use explicit FileHandle writes for LaunchAgent redirection to work.

### Action Buttons Not Working

**Check:**
1. Action data in `userInfo`: `content.userInfo["actionData"] = ...`
2. `pendingActions` dictionary populated before notification sent
3. Command has proper path (use full paths like `/usr/bin/open`)

### Code Signing Failures

**Never use sudo for make install** - causes build artifacts to be owned by root, breaking subsequent builds.

**Fix:** Clean with `rm -rf build/` if owned by root.

## API Reference

### POST /notify

**Request:**
```json
{
  "notification": {
    "title": "Required Title",
    "message": "Required Message",
    "subtitle": "Optional",
    "group": "group-id",
    "sound": "/path/to/sound.aiff",
    "interruptionLevel": "timeSensitive",
    "attachment": "/path/to/image.png",
    "action": {
      "id": "action_1",
      "label": "Open",
      "type": "open",
      "location": "/path/to/file"
    },
    "actions": [
      {
        "id": "action_1",
        "label": "View",
        "type": "exec",
        "exec": "/bin/bash",
        "args": ["-c", "open https://example.com"]
      }
    ]
  }
}
```

**Success Response (200):**
```json
{
  "status": "OK",
  "message": "Notification sent"
}
```

**Error Response (400):**
```json
{
  "error": "Invalid JSON",
  "message": "The data couldn't be read...",
  "receivedBody": "{...}",
  "parsedKeys": ["notification"],
  "notificationKeys": ["title", "message", ...]
}
```

### GET /health

Returns `200 OK`

### GET /version

Returns current git commit hash (e.g., `"27f40d7"`)

## Authentication

- Token stored in `~/.dandy-notifier-token`
- Auto-generated on first run
- Permissions: 0600 (user read/write only)
- Sent as: `Authorization: Bearer <token>`

## Testing Examples

```bash
# Basic notification
dandy-notify -t "Hello" -m "World"

# All interruption levels
dandy-notify -i passive -t "Passive" -m "Minimal"
dandy-notify -i active -t "Active" -m "Normal"
dandy-notify -i timeSensitive -t "Important" -m "Focus bypass"
dandy-notify -i critical -t "URGENT" -m "Always shows"

# With attachment
dandy-notify -t "Screenshot" -m "Check this" -a "/path/to/image.png"

# With callback
dandy-notify -t "Deploy" -m "Click to verify" -e "curl https://api.example.com/status"

# Combined
dandy-notify \
  -t "Build Report" \
  -s "CI Pipeline" \
  -m "Tests passed, coverage 87%" \
  -i timeSensitive \
  -a "https://example.com/coverage-badge.png" \
  -e "open https://dashboard.example.com" \
  -g "ci-pipeline"
```

## Evolution of the Project

### Original Issue
Git hook notifications had action buttons that didn't work because `NSWorkspace.open()` fails from background processes.

### Initial Solution
Created HTTP server to move notification handling to GUI context.

### Discovered Issues
1. `open` command fails silently on missing files
2. `pendingActions` dictionary lost on app restart
3. `print()` doesn't log in GUI apps
4. URLSession connection reuse caused empty request bodies
5. HTTP body parsing bug corrupted JSON

### Final Architecture
- Action data stored in notification `userInfo` (persists)
- Shell command execution via `--execute` (allows pre-checks)
- Structured action API with `exec` and `args`
- FileHandle-based logging for LaunchAgent compatibility
- curl-based CLI for reliability
- Auto-updating version from git

## Future Enhancements

Potential features to add:
- Multiple attachments (currently limited to 1)
- Reply text input actions
- Notification scheduling/delays
- Badge count support
- Thread identifiers for grouping
- Custom notification sounds from URLs
- Webhook callbacks on action clicks

