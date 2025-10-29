# Installation Guide

## Quick Install

```bash
make install
```

This will:
1. Build the app in Release mode
2. Install to `/Applications/DandyNotifier.app`
3. Install CLI tool to `/usr/local/bin/dandy-notify`
4. Set up LaunchAgent for auto-start
5. Start the app

## Manual Installation

### 1. Build the App

Using Xcode:
```bash
open DandyNotifier.xcodeproj
# Build for Release (Cmd+B with Release configuration)
```

Using command line:
```bash
xcodebuild -project DandyNotifier.xcodeproj \
  -scheme DandyNotifier \
  -configuration Release \
  build
```

### 2. Install the App

```bash
sudo cp -R build/Build/Products/Release/DandyNotifier.app /Applications/
```

### 3. Grant Permissions

First launch:
```bash
open /Applications/DandyNotifier.app
```

The app will:
- Request notification permissions (click "Allow")
- Create auth token at `~/.dandy-notifier-token`
- Start HTTP server on port 8889
- Show bell icon in menu bar

### 4. Install CLI Tool (Optional)

```bash
sudo cp CLI/dandy-notify /usr/local/bin/
sudo chmod +x /usr/local/bin/dandy-notify
```

### 5. Setup Auto-Start (Optional)

```bash
cp LaunchAgent/com.orthly.DandyNotifier.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.orthly.DandyNotifier.plist
```

## Verification

Check that everything is working:

```bash
make status
```

Or manually:

```bash
# Check if app is running
pgrep DandyNotifier

# Check if server is responding
curl http://localhost:8889/health

# Check if token exists
cat ~/.dandy-notifier-token

# Send a test notification
./test-notification.sh
```

## Testing

Run the test suite:

```bash
make test
```

Or send a manual test:

```bash
dandy-notify -t "Test" -m "Hello from DandyNotifier!"
```

## Troubleshooting

### App won't start
- Check Console.app for crash logs
- Verify entitlements are correct
- Try running from Terminal to see errors:
  ```bash
  /Applications/DandyNotifier.app/Contents/MacOS/DandyNotifier
  ```

### Notifications don't appear
1. Open System Settings > Notifications
2. Find "DandyNotifier" in the list
3. Enable "Allow Notifications"
4. Set alert style to "Alerts" (not "Banners")

### Port 8889 already in use
Check what's using the port:
```bash
lsof -i :8889
```

Kill the conflicting process or modify the port in `NotificationServer.swift`.

### Action buttons don't work
- Ensure you're using `file://` URLs for file paths
- Verify the file exists
- Check that the app has file access permissions

### CLI command not found
```bash
which dandy-notify
# Should output: /usr/local/bin/dandy-notify

# If not, reinstall:
sudo cp CLI/dandy-notify /usr/local/bin/
```

### Permission denied errors
The app needs to be non-sandboxed to access arbitrary files. This is configured in the entitlements file.

## Uninstallation

```bash
make uninstall
```

This will remove:
- The app from `/Applications`
- CLI tool from `/usr/local/bin`
- LaunchAgent from `~/Library/LaunchAgents`
- Auth token from `~/.dandy-notifier-token`

## Security Notes

- The server only accepts connections from localhost
- Authentication token is stored with `0600` permissions
- Token is automatically generated on first run
- The app is not sandboxed (required for file access)

## System Requirements

- macOS 13.0 (Ventura) or later
- Notification permissions
- Network permissions (localhost only)


