#!/usr/bin/env bash
# multigravity.sh - CLI and AppleScript helper for Multigravity
set -euo pipefail

PROFILES_DIR="${AGY_PROFILES_DIR:-$HOME/.antigravity_profiles}"
TARGET_DIRS=("${AGY_TARGET_APP:-$HOME/Library/Application Support/Antigravity}" "${AGY_TARGET_GEMINI:-$HOME/.gemini/antigravity}" "${AGY_TARGET_CLI:-$HOME/.gemini/antigravity-cli}")

current_file() {
  echo "$PROFILES_DIR/.current"
}

ensure_profiles_dir() {
  mkdir -p "$PROFILES_DIR"
}

notify() {
  local msg="$1"
  if [[ "${AGY_HEADLESS:-0}" == "1" ]]; then
    echo "[Multigravity] $msg"
  else
    osascript -e "display notification \"$msg\" with title \"Multigravity\"" 2>/dev/null || echo "$msg"
  fi
}

alert() {
  local msg="$1"
  if [[ "${AGY_HEADLESS:-0}" == "1" ]]; then
    echo "[Alert] $msg" >&2
  else
    osascript -e "display alert \"Multigravity\" message \"$msg\" as critical" 2>/dev/null || echo "$msg" >&2
  fi
}

save_current() {
  local name="$1"
  if [[ -z "$name" ]]; then
    echo "Profile name cannot be empty." >&2
    return 1
  fi
  ensure_profiles_dir
  name="$(echo "$name" | tr -cd '[:alnum:]_-.@ ' | xargs)"
  if [[ -z "$name" ]]; then
    echo "Invalid profile name." >&2
    return 1
  fi

  local dest="$PROFILES_DIR/$name"
  mkdir -p "$dest"

  local saved_any=0
  for dir in "${TARGET_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
      local base
      base="$(basename "$dir")"
      rm -rf "$dest/$base"
      cp -R "$dir" "$dest/$base"
      saved_any=1
    fi
  done

  if [[ $saved_any -eq 0 ]]; then
    mkdir -p "$dest/empty_placeholder"
  fi

  echo "$name" > "$(current_file)"
  notify "Profile '$name' saved successfully."
}

list_profiles() {
  if [[ ! -d "$PROFILES_DIR" ]]; then
    return
  fi
  find "$PROFILES_DIR" -mindepth 1 -maxdepth 1 -type d ! -name '.*' -exec basename {} \; | sort
}

get_current_profile() {
  local cf
  cf="$(current_file)"
  if [[ -f "$cf" ]]; then
    cat "$cf"
  else
    echo ""
  fi
}

switch_profile() {
  local target_name="$1"
  local src="$PROFILES_DIR/$target_name"

  if [[ ! -d "$src" ]]; then
    alert "Profile '$target_name' does not exist."
    return 1
  fi

  local current
  current="$(get_current_profile)"
  if [[ -n "$current" && "$current" != "$target_name" && -d "$PROFILES_DIR/$current" ]]; then
    for dir in "${TARGET_DIRS[@]}"; do
      if [[ -d "$dir" ]]; then
        local base
        base="$(basename "$dir")"
        rm -rf "$PROFILES_DIR/$current/$base"
        cp -R "$dir" "$PROFILES_DIR/$current/$base"
      fi
    done
  fi

  if [[ "${AGY_HEADLESS:-0}" == "0" ]]; then
    if pgrep -fi "Antigravity" >/dev/null 2>&1; then
      osascript -e 'tell application "Antigravity" to quit' 2>/dev/null || pkill -fi "Antigravity" 2>/dev/null || true
      sleep 1
    fi
  fi

  for dir in "${TARGET_DIRS[@]}"; do
    local base
    base="$(basename "$dir")"
    if [[ -d "$src/$base" ]]; then
      rm -rf "$dir"
      mkdir -p "$(dirname "$dir")"
      cp -R "$src/$base" "$dir"
    fi
  done

  echo "$target_name" > "$(current_file)"
  notify "Switched to profile '$target_name'."
}

run_test() {
  local test_dir
  test_dir="$(mktemp -d /tmp/multigravity_test.XXXXXX)"
  export AGY_PROFILES_DIR="$test_dir/profiles"
  export AGY_TARGET_APP="$test_dir/active/app"
  export AGY_TARGET_GEMINI="$test_dir/active/gemini"
  export AGY_TARGET_CLI="$test_dir/active/cli"
  export AGY_HEADLESS=1

  PROFILES_DIR="$AGY_PROFILES_DIR"
  TARGET_DIRS=("$AGY_TARGET_APP" "$AGY_TARGET_GEMINI" "$AGY_TARGET_CLI")

  mkdir -p "$AGY_TARGET_APP" "$AGY_TARGET_GEMINI" "$AGY_TARGET_CLI"
  echo "user1_token" > "$AGY_TARGET_APP/token.txt"

  save_current "user1@example.com"
  test -f "$AGY_PROFILES_DIR/user1@example.com/app/token.txt" || { echo "Test failed: app token not saved"; exit 1; }
  test "$(get_current_profile)" = "user1@example.com" || { echo "Test failed: current profile mismatch"; exit 1; }

  echo "user2_token" > "$AGY_TARGET_APP/token.txt"
  save_current "user2@example.com"
  test "$(get_current_profile)" = "user2@example.com" || { echo "Test failed: current profile mismatch"; exit 1; }

  switch_profile "user1@example.com"
  test "$(cat "$AGY_TARGET_APP/token.txt")" = "user1_token" || { echo "Test failed: switch to user1 failed"; exit 1; }

  switch_profile "user2@example.com"
  test "$(cat "$AGY_TARGET_APP/token.txt")" = "user2_token" || { echo "Test failed: switch to user2 failed"; exit 1; }

  rm -rf "$test_dir"
  echo "All self-tests passed successfully."
}

case "${1:-}" in
  save)
    save_current "${2:-}"
    ;;
  switch)
    switch_profile "${2:-}"
    ;;
  list)
    list_profiles
    ;;
  current)
    get_current_profile
    ;;
  --test)
    run_test
    ;;
  *)
    echo "Usage: $0 {save|switch|list|current|--test} [name]"
    ;;
esac
