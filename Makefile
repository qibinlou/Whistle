# Makefile for Whistle - AI-powered dictation tool

.PHONY: help get upgrade clean run run-web build dmg analyze format format-check test icons check

# Default target
.DEFAULT_GOAL := help

help: ## Display this help message
	@echo "Whistle Build Commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

get: ## Resolve and fetch Dart packages
	flutter pub get

upgrade: ## Upgrade Dart package dependencies
	flutter pub upgrade

clean: ## Clean Flutter build cache and target directories
	flutter clean

run: ## Run the application on macOS in debug mode
	flutter run -d macos

run-web: ## Run the application on Chrome in debug mode
	flutter run -d chrome

build: ## Build the macOS application in release mode
	flutter build macos --release

dmg: build ## Package the release macOS app into a DMG installer
	chmod +x ./installers/macos/build.sh
	./installers/macos/build.sh

analyze: ## Run static analysis (linting) on the Dart code
	flutter analyze

format: ## Format all Dart source files in the project
	dart format .

format-check: ## Check if all Dart source files are correctly formatted
	dart format --output=none --set-exit-if-changed .

test: ## Run unit and widget tests
	flutter test

icons: ## Generate macOS launcher icons from configuration in pubspec.yaml
	dart run flutter_launcher_icons

check: format-check analyze test ## Run formatting, lint analysis, and tests to verify code quality
