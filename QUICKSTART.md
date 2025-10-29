# Quick Start Guide

Get DandyNotifier running in 5 minutes.

## 1. Install

### For Development (Testing without installing):
```bash
cd /path/to/DandyNotifier
make dev
```

### For Production (Install to /Applications):
```bash
cd /path/to/DandyNotifier
make install
```

You'll be prompted for your password (sudo). The app will automatically start.

> **Tip:** Use `make dev` during development to avoid conflicts. Use `make install` for daily use.

## 2. Verify

Look for the bell icon (🔔) in your menu bar. If you see it, the server is running!

Or check programmatically:

```bash
make status
```

## 3. Test

Send your first notification:

```bash
dandy-notify -t "Hello" -m "DandyNotifier is working!"
```

You should see a notification appear. ✅

## 4. Test Action Buttons

This is the key feature - action buttons that work from background processes!

```bash
# Create a test log file
echo "This is a test log" > /tmp/test.log

# Send notification with action button
dandy-notify \
  -t "Action Test" \
  -m "Click the button to open the log" \
  -o "file:///tmp/test.log"
```

Click the "Open" button on the notification. The log file should open in Console.app or TextEdit.

## 5. Use in Git Hooks

Replace your `terminal-notifier` calls with `dandy-notify`:

**Before:**
```bash
terminal-notifier \
  -title "orthlyweb" \
  -subtitle "post-checkout hook" \
  -message "Command failed" \
  -open "file://$log_file" \
  -group "checkout" \
  -sound "Tink"
```

**After:**
```bash
dandy-notify \
  -t "orthlyweb" \
  -s "post-checkout hook" \
  -m "Command failed" \
  -o "file://$log_file" \
  -g "checkout" \
  --sound "/System/Library/Sounds/Tink.aiff"
```

Copy example hooks:

```bash
# For your specific project
cp examples/git-hooks/post-checkout /path/to/your/repo/.git/hooks/
chmod +x /path/to/your/repo/.git/hooks/post-checkout
```

## 6. Test from Background

The real test - does it work from a background script?

```bash
# Run in background (simulates git hook environment)
(./examples/background-task-example.sh &)
```

You should see notifications even though the script is running in the background. The action buttons should work perfectly!

## Common Use Cases

### Build notifications
```bash
if ! npm run build; then
  dandy-notify \
    -t "Build Failed" \
    -m "Click to view build log" \
    -o "file:///tmp/build.log" \
    --sound "/System/Library/Sounds/Basso.aiff"
fi
```

### Test notifications
```bash
npm test 2>&1 | tee /tmp/test.log
if [ ${PIPESTATUS[0]} -ne 0 ]; then
  dandy-notify \
    -t "Tests Failed" \
    -m "Click to view test results" \
    -o "file:///tmp/test.log"
fi
```

### Deployment notifications
```bash
dandy-notify \
  -t "Deployment" \
  -s "Production" \
  -m "Deploy completed successfully" \
  -g "deployments" \
  --sound "/System/Library/Sounds/Glass.aiff"
```

### Long-running task notifications
```bash
./long-task.sh && \
  dandy-notify -t "Task Complete" -m "Your long task finished!"
```

## Tips

1. **Use groups** (`-g`) to organize related notifications
2. **Custom sounds** make different notification types recognizable
3. **Action buttons** are perfect for "click to view logs" scenarios
4. **Set alert style to "Alerts"** in System Settings for persistent notifications
5. **Keep the app running** - it's lightweight and starts automatically

## Next Steps

- Read [README.md](README.md) for detailed API documentation
- Check [examples/](examples/) for more use cases
- Customize the app icon or menu bar icon if desired
- Share with your team!

## Troubleshooting One-Liners

```bash
# Is it running?
pgrep DandyNotifier

# Is the server responding?
curl http://localhost:8889/health

# View server logs (if using LaunchAgent)
tail -f /tmp/DandyNotifier.log

# Restart the app
killall DandyNotifier && open /Applications/DandyNotifier.app

# Full reinstall
make uninstall && make install
```

## Getting Help

If something doesn't work:

1. Check `make status` output
2. Look at Console.app for "DandyNotifier" logs
3. Verify notification permissions in System Settings
4. Try running the test suite: `make test`

The most common issue is notification permissions. Make sure:
- "Allow Notifications" is enabled
- **Alert style is set to "Alerts"** (not "Banners") - THIS IS CRITICAL!
  - Alerts stay on screen until dismissed
  - Action buttons show as prominent bordered sections
  - Banners auto-dismiss and hide action buttons
- DandyNotifier appears in System Settings > Notifications

---

**That's it!** You now have a working notification server that solves the background process action button problem. 🎉


