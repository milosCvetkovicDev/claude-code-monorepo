---
name: tmux-keybinding-constraints
description: tmux + iTerm2 on Mac — iTerm2 keymaps are EMPTY (it does NOT capture Ctrl-a); the old "iTerm captures it" theory was disproved 2026-06-07. Option-as-Meta `bind -n M-<key>` bindings are the established working pattern. sessionx plugin removed; use built-in `choose-tree -Zs` (Option+s). escape-time MUST be nonzero (set to 50 on 2026-06-10; 10 still leaked under CPU load) or M-bindings break.
type: feedback
originSessionId: 00000000-0000-0000-0000-000000000050
---

## iTerm2 does NOT capture Ctrl-a — verified 2026-06-07

Earlier belief was that iTerm2 swallowed `C-a` so the tmux prefix never worked. **Disproved by inspecting `~/Library/Preferences/com.googlecode.iterm2.plist`:** `GlobalKeyMap` is empty, the Default profile's `Keyboard Map` has 0 entries, no Karabiner, no dynamic profiles. Nothing intercepts Ctrl-a. A fresh `tmux new-session` confirms `prefix C-a` is set cleanly. The original failure was almost certainly a **stale tmux server** started before `set -g prefix C-a` was added (changing prefix needs the server to reload), not the terminal.

**Why:** Avoid re-spending diagnostic cycles blaming iTerm2. If prefix chords ever "do nothing" again, first `tmux kill-server` and retest on a fresh server before suspecting the terminal.

**How to apply:** The ergonomic `C-a` prefix should work. Note: Left+Right Option are both set to **Esc+** in iTerm2 (`Option Key Sends: 2`), which is exactly what makes `bind -n M-<key>` (Meta/Option) bindings work — keep using those for no-prefix global actions (`M-1..9`, `M-s`, `M-[`, `M-]`). A keypress re-test of `C-a |` was left to the user 2026-06-07; if confirmed working, both prefix-chords AND Meta bindings are available.

## sessionx removed — use `choose-tree -Zs`

`omerxx/tmux-sessionx` was broken (Homebrew-bash arithmetic crash on multi-session `list-sessions`). **Removed from `~/.tmux.conf` entirely 2026-06-07** (plugin line, `@sessionx-*` settings, and the dead `M-o` binding). The session picker is built-in `choose-tree -Zs` bound to **Option+s** (`M-s`).

## escape-time 0 silently breaks all M-bindings — fixed 2026-06-10

`set -sg escape-time 0` (was line 14) broke `M-s` & co.: Option sends `Esc`+`s` as two bytes, and with a 0ms escape timeout tmux can split them into a standalone Escape plus a plain `s`. Binding/iTerm2 config were all correct — only the timeout was at fault. **Fix: `set -sg escape-time 50`** (10 still leaked split reads under heavy CPU load; 50 remains imperceptible for Vim Esc). Note: tmux-sensible would force 0 if the option were left at default — the explicit line 14 setting preempts it. If M-bindings die again, check this FIRST, then stale server, and never blame iTerm2 (Option Key Sends = 2 / Esc+ confirmed stable). Fallback that always works: `C-a s` (prefix-table choose-tree).

## Config cleanup applied 2026-06-07

In `~/.tmux.conf`: truecolor migrated to `set -as terminal-features ",xterm-256color:RGB"`; added `detach-on-destroy off` (killing a session switches rather than exits); `status-interval` 5→60 (clock is minute-resolution); added `@continuum-boot 'on'` (auto-start tmux on iTerm2 launch — pairs with `cc`/`ccw` aliases). All validated via throwaway server, parses exit 0.
