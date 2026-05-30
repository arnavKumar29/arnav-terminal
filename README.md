<div align="center">
  <img src="public/logo.png" width="144" height="144" alt="Arnav Terminal" />
  <h1>Arnav Terminal</h1>

  <p><strong>Your Next-Generation AI Workspace</strong></p>

  <p>
    <a href="https://github.com/arnavKumar29/arnav-terminal"><img src="https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-black" alt="Platform" /></a>
    <a href="https://github.com/arnavKumar29/arnav-terminal/releases/latest"><img src="https://img.shields.io/github/v/release/arnavKumar29/arnav-terminal?color=success" alt="Release" /></a>
  </p>
</div>

---

Welcome to **Arnav Terminal**, a high-performance, aesthetically pleasing, and AI-first development environment. Built from the ground up for speed, power, and elegance, Arnav Terminal blends a lightning-fast Rust backend with an ultra-modern React frontend.

## Why Arnav Terminal?

- **Unmatched Speed:** Powered by Tauri 2 and Rust, delivering native PTY execution with a WebGL-accelerated terminal (xterm.js).
- **AI-Native:** It doesn't just have chat—it has *context*. Use Anthropic, OpenAI, or fully local models (Ollama, LM Studio) to edit your code, run bash commands, and manage your projects autonomously.
- **Floating UI Aesthetic:** A unique glassmorphism and rounded-corner design gives your workspace a truly futuristic feel.
- **Zero Bloat:** Completely local-first philosophy. No telemetry, no forced accounts, no hidden background tracking. 

## Core Capabilities

### The Terminal
- Ultra-fast WebGL rendering engine.
- Split-pane support (horizontal and vertical) for advanced multitasking.
- Direct integration with Windows WSL and PowerShell out of the box.

### The Intelligence
- Agentic workflows that can read, write, grep, and execute terminal commands (with your permission).
- Custom AI agents configured directly to your workflow.
- Secure API key management stored in your OS keychain.

### The Editor
- Integrated CodeMirror 6 with support for dozens of languages.
- Real-time AI autocomplete and hunk-by-hunk diff reviewing.
- Multi-theme support independent of the terminal theme.

### The Preview & Explorer
- Built-in web preview for your local dev servers (localhost).
- Native file explorer with fuzzy searching and context menus.
- Stage, commit, and push straight from the integrated Git Graph UI.

## Getting Started

### Installation
Head over to the [Releases](https://github.com/arnavKumar29/arnav-terminal/releases/latest) page and download the installer for your OS. The terminal will automatically keep itself updated.

> **Windows Users:** On the very first run, Windows SmartScreen may pop up. Just click **More info** -> **Run anyway**. 

### Adding Your AI Brain
1. Open the **Settings** menu.
2. Navigate to the **AI** section.
3. Select your provider (e.g., Anthropic, Gemini, Groq) and drop in your API key, or point it to your local model endpoint.

## Build It Yourself

Want to tinker? Here's how to build Arnav Terminal from source:

```bash
# Install dependencies
pnpm install

# Run the development server
pnpm tauri dev

# Build the final executable
pnpm tauri build
```

**Requirements:** Node.js 20+, pnpm, and Rust stable.

---
*Arnav Terminal - Engineered for the modern developer.*
