# Development Guide

## Development vs Production Modes

DandyNotifier supports two modes:

### 🔧 Development Mode
Runs from the build directory without installing. Perfect for testing changes.

```bash
make dev    # Builds and runs from build/
make test   # Run tests
killall DandyNotifier  # Stop when done
```

**What `make dev` does:**
1. Kills any running instances (dev or installed)
2. Unloads LaunchAgent (if present)
3. Runs app from `build/Build/Products/Release/DandyNotifier.app`
4. Starts server on port 8889
5. Creates token at `~/.dandy-notifier-token`

### 🚀 Production Mode
Installs to `/Applications` and sets up auto-start.

```bash
make install    # Install everything
make test       # Run tests
make uninstall  # Remove everything
```

**What `make install` does:**
1. Builds the app
2. Installs to `/Applications/DandyNotifier.app`
3. Installs CLI to `/usr/local/bin/dandy-notify`
4. Sets up LaunchAgent for auto-start
5. Starts the app

## Typical Development Workflow

### Making Changes

```bash
# 1. Edit code in Xcode or your editor
vim DandyNotifier/DandyNotifierApp.swift

# 2. Test your changes
make dev          # Rebuilds and restarts

# 3. Run tests
make test

# 4. Check status
make status

# 5. Stop when done
killall DandyNotifier
```

### Avoiding Port Conflicts

Only **one instance** can run at a time (port 8889). If you get "Address already in use":

```bash
# Check what's running
pgrep -fl DandyNotifier
lsof -i :8889

# Kill everything
killall DandyNotifier
launchctl unload ~/Library/LaunchAgents/com.orthly.DandyNotifier.plist 2>/dev/null

# Start fresh
make dev
```

## Common Development Tasks

### Running Tests Without Installing

```bash
make dev      # Start from build dir
make test     # Run test suite
```

### Debugging

```bash
# Run in foreground to see console output
make run      # Blocks terminal, shows all logs

# Or run in background and tail logs
make dev
log stream --predicate 'process == "DandyNotifier"' --level debug
```

### Quick Iteration

```bash
# One-liner: rebuild, restart, test
make dev && make test
```

### Switching Between Dev and Production

```bash
# Switch to production
make uninstall  # Clean up any old install
make install    # Fresh production install

# Switch to dev
killall DandyNotifier
launchctl unload ~/Library/LaunchAgents/com.orthly.DandyNotifier.plist
make dev
```

## Project Structure

```
DandyNotifier/
├── DandyNotifier/              # Main app source
│   ├── DandyNotifierApp.swift  # App delegate, menu bar
│   ├── NotificationServer.swift # HTTP server
│   └── NotificationManager.swift # Notification handling
├── CLI/
│   └── dandy-notify            # Command-line client
├── Makefile                    # Build automation
└── test-notification.sh        # Test suite
```

## Build System

### Targets

| Command | What It Does | When to Use |
|---------|--------------|-------------|
| `make dev` | Build + run from build dir | Development, testing changes |
| `make install` | Build + install to /Applications | Production use, distribution |
| `make test` | Run notification tests | Verify functionality |
| `make build` | Just build, don't run | CI/CD, verify it compiles |
| `make clean` | Remove build artifacts | Free disk space |
| `make status` | Check what's running | Troubleshooting |
| `make run` | Run in foreground | Debugging (blocks terminal) |

### Build Configuration

- **Configuration:** Release (optimized)
- **Target:** macOS 15.6+ (Sequoia)
- **Architecture:** arm64 (Apple Silicon) + x86_64 (Intel)
- **Sandboxing:** Disabled (required for file access)

## Testing

### Manual Testing

```bash
# Start dev server
make dev

# Send test notification
dandy-notify -t "Test" -m "Hello"

# Test with action button
echo "Test log" > /tmp/test.log
dandy-notify -t "Action Test" -m "Click to open" -o "file:///tmp/test.log"
```

### Automated Testing

```bash
make test
```

This runs `test-notification.sh` which verifies:
- ✓ Server is running
- ✓ Authentication works
- ✓ Simple notifications
- ✓ Notifications with subtitles
- ✓ Action buttons
- ✓ Grouped notifications
- ✓ Custom sounds

### Testing from Background Scripts

```bash
# Simulates git hook environment
(./examples/background-task-example.sh &)
```

## Troubleshooting

### App Won't Start

```bash
# Check if something is using port 8889
lsof -i :8889

# Check for crashes
log show --predicate 'process == "DandyNotifier"' --last 5m

# Try clean rebuild
make clean
make dev
```

### Tests Fail

```bash
# Make sure app is running
pgrep DandyNotifier

# Check server health
curl http://localhost:8889/health

# Verify token exists
ls -la ~/.dandy-notifier-token
```

### Permission Errors

```bash
# The app must be non-sandboxed
# Check in Xcode: Build Settings > App Sandbox = NO

# Or verify in build settings
grep ENABLE_APP_SANDBOX DandyNotifier.xcodeproj/project.pbxproj
# Should show: ENABLE_APP_SANDBOX = NO;
```

## Code Style

- Swift code follows standard conventions
- 4-space indentation
- Clear, descriptive variable names
- Comments for complex logic
- Error handling with helpful messages

## Contributing

1. Make your changes
2. Test with `make dev && make test`
3. Update documentation if needed
4. Commit with clear message
5. Test installation: `make uninstall && make install`

## Performance

The app is designed to be lightweight:
- **Memory:** ~15-20 MB resident
- **CPU:** <1% idle, ~2-3% when processing
- **Startup:** <1 second
- **Latency:** <50ms from HTTP request to notification

Keep performance in mind when making changes!

