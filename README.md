# Multigravity

> Native macOS menu bar (tray) account switcher and multi-account manager for Google Antigravity.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: macOS](https://img.shields.io/badge/Platform-macOS-lightgrey.svg)](https://apple.com/macos)
[![Binary Size](https://img.shields.io/badge/Binary-~75%20KB-brightgreen.svg)]()
[![Dependencies: 0](https://img.shields.io/badge/Dependencies-0-success.svg)]()

When intensive coding or long autonomous agent sessions exhaust your model quotas (HTTP 429 / `RESOURCE_EXHAUSTED` / rolling 5-hour limits), **Multigravity** lets you switch between authenticated Google accounts in a single click directly from your macOS menu bar.

---

## Features

- ⚡ **Pure Native macOS App**: Built with native AppKit/Cocoa. Only ~75 KB, zero Electron/Node overhead, 0 MB idle RAM.
- 🎯 **Menu Bar Resident**: Sits quietly in your menu bar (tray) with no Dock clutter (`LSUIElement`).
- 🔍 **Auto-Detection**: Automatically detects your active logged-in Google account on launch from Antigravity session storage.
- 🔄 **One-Click Switch**: Displays all saved accounts with a checkmark on the active one. Click any profile to seamlessly swap credentials and restart Antigravity.
- ➕ **Add & Log In New Accounts**: Click *"+ Add / Log In New Account..."* to stash the current session and open Antigravity fresh for a new Google OAuth sign-in.
- 🛡️ **Session Preservation**: Automatically saves token updates and session changes back to the active profile before switching.
- 💻 **CLI Included**: Companion shell script (`cli/multigravity.sh`) for automated terminal scripting and CI workflows.

---

## Quick Start

### 1. Build and Run

Clone the repository and run the build script:

```bash
git clone https://github.com/adalenv/multigravity.git
cd multigravity
./build.sh
open "Multigravity.app"
```

To install it permanently, move `Multigravity.app` into `/Applications`:

```bash
cp -R "Multigravity.app" /Applications/
```

---

## How It Works

```
Menu Bar Tray Click
      │
      ├─── Active Account Checkmark (✓ user1@gmail.com)
      │
      ├─── Click user2@gmail.com
      │      ├── 1. Auto-save user1 tokens to ~/.antigravity_profiles/user1@gmail.com/
      │      ├── 2. Gracefully quit running Antigravity instances
      │      ├── 3. Restore user2 tokens into ~/.gemini/ and ~/Library/Application Support/
      │      └── 4. Relaunch Antigravity logged in as user2
      │
      └─── "＋ Add / Log In New Account..."
             ├── 1. Prompt for account label (e.g. work@example.com)
             ├── 2. Stash active session
             ├── 3. Clean active directories for fresh Google sign-in
             └── 4. Launch Antigravity to complete OAuth onboarding
```

### Managed Paths

Multigravity synchronizes the following Antigravity runtime locations:
- `~/.gemini/antigravity/` (agent configurations, conversation databases, installation UUID)
- `~/.gemini/antigravity-cli/` (CLI OAuth tokens, `settings.json`)
- `~/Library/Application Support/Antigravity/` (IDE local storage, `app_storage.json`, browser session cookies)

All profiles are isolated locally in `~/.antigravity_profiles/`.

---

## CLI Usage

For headless automation or scripting:

```bash
# Save current active session
./cli/multigravity.sh save "work@example.com"

# Switch to a profile
./cli/multigravity.sh switch "personal@gmail.com"

# List profiles
./cli/multigravity.sh list

# Run self-test verification
./cli/multigravity.sh --test
```

---

## Companion Tool

Looking for headless auto-failover directly inside the terminal for `agy` CLI? Check out [zerog](https://github.com/adalenv/zerog) (`@adalenv/zerog` on npm).

---

## License

MIT © [Adalen Vladisavljevic](https://github.com/adalenv)
