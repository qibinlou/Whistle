# GitHub Copilot Instructions for Whistle

## Project Overview

Whistle is an AI-powered dictation tool built with Flutter for macOS. It's designed for speed and minimalism, providing seamless speech-to-text conversion with system-wide hotkeys. The app integrates with OpenAI's transcription models (Whisper and gpt-4o-transcribe) to deliver accurate voice-to-text functionality.

## Key Technologies & Architecture

- **Framework**: Flutter (SDK ^3.5.3)
- **Platform**: macOS (with potential for Windows/Linux expansion)
- **AI Integration**: OpenAI API (Whisper, gpt-4o-transcribe models)
- **System Integration**: macOS accessibility APIs, system-wide hotkeys
- **Size**: Lightweight (<50MB total app size)


## Development Guidelines

### Code Style & Architecture

- Mostly importantly follow existing code naming conventions, styles, structures and patterns
- Follow the principle of separation of concerns
- Follow Flutter/Dart best practices
- Maintain minimal, clean codebase
- Prioritize performance and low resource usage
- Use dependency injection for service management
- Implement proper error handling and user feedback

### Privacy & Security

- No data logging or tracking
- User-provided API keys only
- Local processing when possible
- Secure storage of sensitive information

### Platform-Specific Considerations

- **macOS Focus**: Primary platform with full feature support
- **Cross-platform Potential**: Design code to be extensible to Windows/Linux
- **System Permissions**: Handle microphone and accessibility permissions gracefully
- **Background Operation**: Minimal resource usage when running in background

## Contribution Guidelines

- Focus on maintaining the lightweight, minimalist nature
- Ensure cross-platform compatibility where possible
- Write comprehensive tests for new features
- Document any new configuration options
- Follow the existing code organization patterns
- Prioritize user privacy and security in all implementations

