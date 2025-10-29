# Project Cleanup Notes

## Removed Files & Configurations

### 1. **DandyNotifyAgent/** directory (Unused Target)
   - This was scaffolding from Xcode's initial project creation
   - Completely removed as we only need one target: `DandyNotifier`
   - Removed from git staging

### 2. **DandyNotifyAgent Scheme**
   - Removed references from `xcschememanagement.plist`
   - Only `DandyNotifier` scheme remains

### 3. **User-Specific Files** (Now Properly Ignored)
   - `xcuserdata/` directories
   - `*.xcuserstate` files
   - `.DS_Store` files
   - These are now in `.gitignore` and won't be tracked in future commits

## Current Project Structure

```
DandyNotifier/
├── .gitignore                  # Comprehensive ignore file
├── CLI/
│   └── dandy-notify           # Command-line tool
├── DandyNotifier/             # Main app target
│   ├── Assets.xcassets/
│   ├── ContentView.swift
│   ├── DandyNotifier.entitlements
│   ├── DandyNotifierApp.swift
│   ├── Info.plist
│   ├── NotificationManager.swift
│   └── NotificationServer.swift
├── DandyNotifier.xcodeproj/   # Xcode project (single target)
├── LaunchAgent/
│   └── com.orthly.DandyNotifier.plist
├── examples/
│   ├── background-task-example.sh
│   └── git-hooks/
├── Makefile                   # Build & install automation
├── README.md                  # Main documentation
├── QUICKSTART.md              # Quick start guide
├── INSTALL.md                 # Installation instructions
├── PROJECT_SUMMARY.md         # Technical deep-dive
└── test-notification.sh       # Test suite
```

## Build Configuration

### Key Settings (All Targets)
- **App Sandbox:** DISABLED (`ENABLE_APP_SANDBOX = NO`)
  - Required for accessing arbitrary files (custom sounds, icons, logs)
  - Required for opening file:// URLs from notifications

- **Entitlements:**
  - `com.apple.security.app-sandbox` = false
  - `com.apple.security.network.server` = true
  - `com.apple.security.network.client` = true

- **Deployment Target:** macOS 15.6 (Sequoia)
  - Compatible with Sequoia (15.x) and future versions
  - Uses modern UserNotifications API (not deprecated NSUserNotification)

## What's NOT in Git

The following are properly ignored:
- `build/` - Build artifacts
- `xcuserdata/` - User-specific Xcode settings
- `*.xcuserstate` - Xcode state files
- `.DS_Store` - macOS Finder metadata
- Swift Package Manager cache
- Derived data

## Clean Install Process

To get a fresh, clean install:

```bash
# Clean everything
rm -rf build/
rm -f ~/Library/LaunchAgents/com.orthly.DandyNotifier.plist
killall DandyNotifier 2>/dev/null

# Fresh install
make install
```

## Notes

- Project uses **zero external dependencies** - only built-in macOS frameworks
- Single target architecture (no multi-target complexity)
- User settings (xcuserdata) are tracked for scheme configuration but changes won't affect others
- All documentation is consolidated in the root directory for easy access

