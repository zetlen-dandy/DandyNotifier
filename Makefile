.PHONY: build clean install uninstall test help

APP_NAME = DandyNotifier
SCHEME = DandyNotifier
BUILD_DIR = build
INSTALL_PATH = /Applications/$(APP_NAME).app
CLI_NAME = dandy-notify
CLI_INSTALL_PATH = /usr/local/bin/$(CLI_NAME)
LAUNCH_AGENT_PLIST = com.orthly.DandyNotifier.plist
LAUNCH_AGENT_PATH = $(HOME)/Library/LaunchAgents/$(LAUNCH_AGENT_PLIST)

help:
	@echo "DandyNotifier - Build and Installation"
	@echo ""
	@echo "Usage:"
	@echo "  make build          Build the app in Release mode"
	@echo "  make dev            Build and run from build dir (development mode)"
	@echo "  make test           Run test notifications (requires app running)"
	@echo "  make install        Install app, CLI, and launch agent (production)"
	@echo "  make uninstall      Remove all installed components"
	@echo "  make clean          Clean build artifacts"
	@echo "  make status         Check installation and server status"
	@echo "  make run            Build and run in foreground (blocks terminal)"
	@echo "  make help           Show this help message"
	@echo ""
	@echo "Development workflow:"
	@echo "  1. make dev         # Start app from build directory"
	@echo "  2. make test        # Run tests"
	@echo "  3. killall DandyNotifier  # Stop when done"
	@echo ""
	@echo "Production workflow:"
	@echo "  1. make install     # Install to /Applications and auto-start"
	@echo "  2. make test        # Run tests"
	@echo ""

build:
	@echo "🔨 Building $(APP_NAME)..."
	@# Update version from git
	@VERSION=$$(git describe --tags --always 2>/dev/null || git rev-parse --short HEAD); \
	sed -i '' "s/static let version = \".*\" *\/\/ Updated via.*/static let version = \"$$VERSION\"  \/\/ Updated via build script/" DandyNotifier/NotificationServer.swift; \
	echo "  Updated version to: $$VERSION"
	xcodebuild -project $(APP_NAME).xcodeproj \
		-scheme $(SCHEME) \
		-configuration Release \
		-derivedDataPath $(BUILD_DIR) \
		clean build
	@echo "✓ Build complete: $(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app"

clean:
	@echo "🧹 Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)
	@echo "✓ Clean complete"

install: build
	@echo "📦 Installing $(APP_NAME)..."
	
	@# Stop existing app
	@if pgrep -x "$(APP_NAME)" > /dev/null; then \
		echo "  Stopping running instance..."; \
		killall $(APP_NAME) 2>/dev/null || true; \
		sleep 1; \
	fi
	
	@# Unload launch agent if exists
	@if [ -f "$(LAUNCH_AGENT_PATH)" ]; then \
		echo "  Unloading launch agent..."; \
		launchctl unload "$(LAUNCH_AGENT_PATH)" 2>/dev/null || true; \
	fi
	
	@# Install app
	@echo "  Installing app to $(INSTALL_PATH)..."
	@sudo rm -rf "$(INSTALL_PATH)"
	@sudo cp -R "$(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app" "$(INSTALL_PATH)"
	
	@# Build and install CLI tool
	@echo "  Building CLI tool..."
	@swiftc -parse-as-library -O -o $(BUILD_DIR)/$(CLI_NAME) CLI.swift
	@echo "  Installing CLI to app bundle..."
	@sudo cp $(BUILD_DIR)/$(CLI_NAME) "$(INSTALL_PATH)/Contents/MacOS/$(CLI_NAME)"
	@sudo chmod +x "$(INSTALL_PATH)/Contents/MacOS/$(CLI_NAME)"
	@echo "  Installing CLI to $(CLI_INSTALL_PATH)..."
	@sudo cp $(BUILD_DIR)/$(CLI_NAME) $(CLI_INSTALL_PATH)
	@sudo chmod +x $(CLI_INSTALL_PATH)
	
	@# Install launch agent
	@echo "  Installing launch agent..."
	@mkdir -p $(HOME)/Library/LaunchAgents
	@cp LaunchAgent/$(LAUNCH_AGENT_PLIST) "$(LAUNCH_AGENT_PATH)"
	@launchctl load "$(LAUNCH_AGENT_PATH)"
	
	@echo ""
	@echo "✅ Installation complete!"
	@echo ""
	@echo "The app should now be running. Check the menu bar for the bell icon."
	@echo ""
	@echo "Test it with:"
	@echo "  make test"
	@echo ""
	@echo "Or manually:"
	@echo "  $(CLI_NAME) -t 'Hello' -m 'World'"

uninstall:
	@echo "🗑️  Uninstalling $(APP_NAME)..."
	
	@# Stop app
	@if pgrep -x "$(APP_NAME)" > /dev/null; then \
		echo "  Stopping app..."; \
		killall $(APP_NAME) 2>/dev/null || true; \
	fi
	
	@# Unload and remove launch agent
	@if [ -f "$(LAUNCH_AGENT_PATH)" ]; then \
		echo "  Removing launch agent..."; \
		launchctl unload "$(LAUNCH_AGENT_PATH)" 2>/dev/null || true; \
		rm -f "$(LAUNCH_AGENT_PATH)"; \
	fi
	
	@# Remove app
	@if [ -d "$(INSTALL_PATH)" ]; then \
		echo "  Removing app..."; \
		sudo rm -rf "$(INSTALL_PATH)"; \
	fi
	
	@# Remove CLI
	@if [ -f "$(CLI_INSTALL_PATH)" ]; then \
		echo "  Removing CLI..."; \
		sudo rm -f "$(CLI_INSTALL_PATH)"; \
	fi
	
	@# Remove auth token
	@if [ -f "$(HOME)/.dandy-notifier-token" ]; then \
		echo "  Removing auth token..."; \
		rm -f "$(HOME)/.dandy-notifier-token"; \
	fi
	
	@echo "✓ Uninstall complete"

run: build
	@echo "🚀 Running $(APP_NAME)..."
	@"$(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app/Contents/MacOS/$(APP_NAME)"

dev: build
	@echo "🔧 Starting development mode..."
	@# Kill any running instances (installed or dev)
	@killall $(APP_NAME) 2>/dev/null || true
	@sleep 1
	@# Unload LaunchAgent if present
	@launchctl unload "$(LAUNCH_AGENT_PATH)" 2>/dev/null || true
	@# Run from build directory in background
	@echo "  Starting $(APP_NAME) from build directory..."
	@"$(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app/Contents/MacOS/$(APP_NAME)" &
	@sleep 2
	@# Check if it started
	@if pgrep -q $(APP_NAME); then \
		echo "✓ $(APP_NAME) running in dev mode (PID: $$(pgrep $(APP_NAME)))"; \
		echo "  Server: http://localhost:8889"; \
		echo "  Logs: Check Console.app or run 'log stream --predicate \"process == \\\"$(APP_NAME)\\\"\"'"; \
		echo ""; \
		echo "To stop: killall $(APP_NAME)"; \
		echo "To test: make test"; \
	else \
		echo "✗ Failed to start $(APP_NAME)"; \
		exit 1; \
	fi

test:
	@echo "🧪 Running test notifications..."
	@# Check if app is running
	@if ! pgrep -q $(APP_NAME); then \
		echo ""; \
		echo "❌ $(APP_NAME) is not running!"; \
		echo ""; \
		echo "Start it first:"; \
		echo "  make dev          # Run from build dir (development)"; \
		echo "  make install      # Install and run (production)"; \
		echo ""; \
		exit 1; \
	fi
	@echo "✓ $(APP_NAME) is running"
	@echo ""
	@./test-notification.sh

status:
	@echo "📊 DandyNotifier Status"
	@echo ""
	@if pgrep -x "$(APP_NAME)" > /dev/null; then \
		echo "  App Status: ✓ Running"; \
	else \
		echo "  App Status: ✗ Not running"; \
	fi
	@if [ -f "$(INSTALL_PATH)/Contents/MacOS/$(APP_NAME)" ]; then \
		echo "  Installed: ✓ $(INSTALL_PATH)"; \
	else \
		echo "  Installed: ✗ Not installed"; \
	fi
	@if [ -f "$(CLI_INSTALL_PATH)" ]; then \
		echo "  CLI: ✓ $(CLI_INSTALL_PATH)"; \
	else \
		echo "  CLI: ✗ Not installed"; \
	fi
	@if [ -f "$(LAUNCH_AGENT_PATH)" ]; then \
		echo "  LaunchAgent: ✓ Installed"; \
	else \
		echo "  LaunchAgent: ✗ Not installed"; \
	fi
	@if [ -f "$(HOME)/.dandy-notifier-token" ]; then \
		echo "  Auth Token: ✓ Present"; \
	else \
		echo "  Auth Token: ✗ Not found"; \
	fi
	@echo ""
	@if command -v curl &> /dev/null; then \
		if curl -s -f http://localhost:8889/health > /dev/null 2>&1; then \
			echo "  Server: ✓ Responding on port 8889"; \
		else \
			echo "  Server: ✗ Not responding"; \
		fi; \
	fi


