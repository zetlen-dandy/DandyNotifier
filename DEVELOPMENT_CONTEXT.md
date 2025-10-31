# DandyNotifier - Development Context & History

## What Is DandyNotifier?

DandyNotifier is a macOS menubar application that runs a local HTTP server for sending advanced macOS notifications with action buttons, attachments, and interruption levels. It was created to solve a specific problem: **Git hooks and other background processes cannot reliably trigger interactive notifications with working action buttons.**

## The Problem It Solves

### Original Issue
When running Git hooks or other background tasks, macOS notifications would appear but action buttons would fail silently when clicked. The core issues were:

1. **Background Process Limitations**: `NSWorkspace.open()` doesn't work reliably from background processes
2. **Action Persistence**: In-memory action handlers are lost when the notification app isn't running  
3. **Silent Failures**: The `open` command fails silently when files don't exist

### The Solution
DandyNotifier runs as a menubar app with a local HTTP server. Any process can send it notifications via HTTP, and the app handles action callbacks in a foreground context where macOS APIs work reliably.

## Architecture

### Components

1. **DandyNotifier App** (menubar)
   - Runs as LaunchAgent (auto-starts on login)
   - HTTP server on port 8889
   - Token-based authentication
   - Logs to `/tmp/DandyNotifier.log` (stdout) and `/tmp/DandyNotifier.error.log` (stderr)

2. **CLI Tool** (`dandy-notify`)
   - Native Swift CLI (not a shell script)
   - Bundled in app at `/Applications/DandyNotifier.app/Contents/MacOS/dandy-notify`
   - Also installed to `/usr/local/bin/dandy-notify`
   - Uses curl via `Process()` for reliable HTTP requests

3. **LaunchAgent** (`com.orthly.DandyNotifier.plist`)
   - Auto-starts server on login
   - Redirects stdout/stderr to log files
   - Configured for manual restart (KeepAlive disabled by default)

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

### Action Types

**Open Type:**
```json
{
  "id": "open_action",
  "label": "Open",
  "type": "open",
  "location": "/path/or/url"
}
```

**Execute Type:**
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
- **Supported types**: images (png, jpg, gif), videos (mp4, mov), audio (mp3, aiff, wav)

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

## Development Workflow

### Build and Install

```bash
make install
```

This automatically:
1. Updates version from `git describe --tags --always`
2. Builds Xcode project
3. Compiles Swift CLI
4. Installs to `/Applications/DandyNotifier.app`
5. Installs CLI to `/usr/local/bin/dandy-notify`
6. Loads LaunchAgent

**NEVER use `sudo`** - causes code signing failures and permission issues.

### Testing Examples

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

# Combined features
dandy-notify \
  -t "Build Report" \
  -s "CI Pipeline" \
  -m "Tests passed, coverage 87%" \
  -i timeSensitive \
  -a "https://example.com/coverage-badge.png" \
  -e "open https://dashboard.example.com" \
  -g "ci-pipeline"
```

### Logging & Debugging

```bash
# Monitor normal operations
tail -f /tmp/DandyNotifier.log

# Monitor errors
tail -f /tmp/DandyNotifier.error.log

# Check server version
curl http://localhost:8889/version

# Debug mode (shows JSON being sent)
dandy-notify -d -t "Test" -m "Message"

# LaunchAgent status
launchctl list | grep DandyNotifier
launchctl print gui/$(id -u)/com.orthly.DandyNotifier
```

## Critical Implementation Details

### HTTP Server

**Why manual implementation instead of a framework?**
- Only 3 endpoints needed
- Zero dependencies
- Lightweight for menubar app
- Full control over parsing

**Body Parsing Bug (FIXED):**
Early versions converted HTTP body to string and back, corrupting binary JSON data. Fixed by extracting body as raw `Data` after finding `\r\n\r\n` separator:

```swift
let headerSeparator = Data([13, 10, 13, 10]) // \r\n\r\n
let bodyData = data.subdata(in: separatorRange.upperBound..<data.count)
```

### CLI Implementation

**Why curl instead of URLSession?**
URLSession had connection reuse issues causing subsequent requests to send empty bodies. Even with `URLSessionConfiguration.ephemeral`, problems persisted. Curl is 100% reliable:

```swift
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
process.arguments = ["-s", "-X", "POST", ...]
```

### Action Execution

**Why Process() instead of NSWorkspace.open()?**
`NSWorkspace.open()` fails silently from background/notification contexts. Using explicit Process() with full command paths is reliable:

```swift
let task = Process()
task.launchPath = "/bin/bash"
task.arguments = ["-c", "open file.txt"]
try? task.run()
```

### Logging in GUI Apps

**Critical Swift Quirk:**
`print()` doesn't write to stdout in macOS GUI apps - it goes nowhere or to the system Console. Must use:

```swift
FileHandle.standardOutput.write(data)  // stdout -> /tmp/DandyNotifier.log
FileHandle.standardError.write(data)   // stderr -> /tmp/DandyNotifier.error.log
```

This is the ONLY way to make LaunchAgent's stdout/stderr redirection work.

### Version Management

Version auto-updates on every build:
- Makefile runs `git describe --tags --always`
- Updates `NotificationServer.swift` before compiling
- Accessible via `/version` endpoint
- Displayed in menubar

## Evolution Timeline

### Phase 1: Basic Notifications
- Simple HTTP server with title + message
- Single action button (didn't work from background)

### Phase 2: Fixing Action Buttons
- Replaced `NSWorkspace.open()` with `/usr/bin/open` via `Process()`
- Stored action data in notification `userInfo` (persists across restarts)
- Added `--execute` flag for shell commands

### Phase 3: Enhanced Actions
- Refactored to structured `exec`/`args` API
- Support for multiple buttons (up to 4)
- Separate "open" and "exec" action types

### Phase 4: Interruption Levels & Reliability
- Added all 4 macOS interruption levels
- **Fixed HTTP body parsing bug** (major breakthrough)
- **Replaced URLSession with curl** (reliability fix)

### Phase 5: Developer Experience
- Debug mode (`-d` flag) with JSON output
- Structured logging with ISO8601 timestamps
- `/version` endpoint for sanity checking
- **Fixed GUI app logging** (FileHandle vs print)
- Auto-versioning from git

### Phase 6: Media Support
- Attachment support (images, videos, audio)
- Local files and remote URLs
- Automatic download of remote attachments

## Common Issues & Solutions

### "Server returned HTTP 400"

**Troubleshoot:**
1. Check error logs: `tail /tmp/DandyNotifier.error.log`
2. Use debug mode: `dandy-notify -d ...`
3. Verify version: `curl http://localhost:8889/version`
4. Test with curl directly to isolate CLI vs server issues

### No Logs Appearing

**Cause:** Using `print()` instead of `FileHandle.standardOutput`  
**Fix:** All logging must use explicit FileHandle writes

### Action Buttons Not Working

**Check:**
1. Action data stored in `userInfo` or `pendingActions`
2. Command has full path (`/usr/bin/open`, not `open`)
3. Check if file exists before trying to open it
4. Use `--execute` with shell check: `[ -f file.txt ] && open file.txt`

### Empty Request Body on Second Request

**Cause:** URLSession connection reuse bug  
**Fixed:** CLI now uses curl via `Process()`

### Code Signing Failures

**Cause:** Running `sudo make install`  
**Fix:** Never use sudo. If build artifacts are owned by root, clean with `rm -rf build/`

## Technical Learnings

### Swift/macOS Quirks Discovered

1. **GUI apps and stdout**: `print()` doesn't write to stdout in macOS GUI apps
2. **Background process limitations**: Many macOS APIs fail silently from background
3. **URLSession reliability**: Can have subtle connection reuse issues
4. **UNNotificationAttachment**: Requires actual file URLs, downloads remote if needed
5. **LaunchAgent logging**: Only works with explicit FileHandle writes, not print()

### HTTP Server Lessons

- Manual parsing is fine for 3 endpoints
- Never convert binary HTTP body to string and back
- Use `Data.range(of: headerSeparator)` to find body start
- JSON error responses are essential for debugging
- Structured logging with timestamps saves hours

### CLI Best Practices

- Native Swift > shell script for complex args
- curl via `Process()` > URLSession for reliability
- Debug mode is essential for troubleshooting
- Always show detailed error responses

## File Organization

```
DandyNotifier/
├── DandyNotifier/           # Main app target
│   ├── NotificationServer.swift    # HTTP server (241 lines)
│   ├── NotificationManager.swift   # UserNotifications (171 lines)
│   ├── DandyNotifierApp.swift      # Menubar app (97 lines)
│   ├── ContentView.swift           # Placeholder SwiftUI view
│   ├── Assets.xcassets/            # App icon (all sizes)
│   ├── Info.plist                  # Minimal config
│   └── DandyNotifier.entitlements  # Network + file access
├── CLI.swift                # Native Swift CLI (245 lines)
├── LaunchAgent/             # Auto-start configuration
│   └── com.orthly.DandyNotifier.plist
├── Makefile                 # Build automation (217 lines)
├── .cursorrules             # Cursor AI guidelines
└── examples/                # Git hooks, samples
```

## Security & Permissions

- **Auth token**: `~/.dandy-notifier-token` (0600 permissions)
- **Server**: localhost-only, no external network access
- **Entitlements**: Network server enabled, app sandbox disabled (needed for command execution)
- **LaunchAgent**: Runs as user, not root

## Future Enhancement Ideas

Potential features to add:
- [ ] Multiple attachments (currently limited to 1)
- [ ] Reply text input actions (`UNTextInputNotificationAction`)
- [ ] Notification scheduling/delays
- [ ] Badge count support
- [ ] Notification history/persistence
- [ ] Custom notification sounds from system library
- [ ] Webhook callbacks on action clicks
- [ ] HTTP framework (Swifter) if endpoints grow beyond 3-4

## References

- [UserNotifications Framework](https://developer.apple.com/documentation/usernotifications)
- [UNNotificationInterruptionLevel](https://developer.apple.com/documentation/usernotifications/unnotificationinterruptionlevel)
- [UNNotificationAttachment](https://developer.apple.com/documentation/usernotifications/unnotificationattachment)
- [LaunchAgent Configuration](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html)

---

## Quick Reference

### Installation
```bash
make install    # Build and install everything
```

### Testing
```bash
dandy-notify -t "Test" -m "Hello World"
```

### Debugging
```bash
# Check version
curl http://localhost:8889/version

# View logs
tail -f /tmp/DandyNotifier.log

# Debug mode
dandy-notify -d -t "Test" -m "Message"
```

### Common Commands
```bash
# Stop server
killall DandyNotifier

# Restart LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.orthly.DandyNotifier.plist
launchctl load ~/Library/LaunchAgents/com.orthly.DandyNotifier.plist

# Check if running
ps aux | grep DandyNotifier | grep -v grep
```
