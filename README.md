# tmux-ws

A shell-native tmux workspace manager. Define workspaces in config files, create them with one command.

## Install

```bash
git clone <repo-url> ~/tmux-ws
cd ~/tmux-ws
./install.sh
```

This copies the config files to `~/.config/tmux-ws/` and adds `bin/` to your PATH (via `~/.bashrc` or `~/.zshrc`).

After install, reload your shell:

```bash
source ~/.bashrc  # or source ~/.zshrc
```

## Usage

```
tmux-ws create <name> [--detach|-d]   Create and attach to a workspace
tmux-ws list                          List available and running workspaces
tmux-ws kill <name>                   Kill a workspace session
tmux-ws edit <name>                   Open workspace config in $EDITOR
tmux-ws init                          Create config directory structure
tmux-ws version                       Show version
tmux-ws help                          Show help
```

### Examples

```bash
# Create a workspace and attach
tmux-ws create project

# Create in background, stay in current shell
tmux-ws create project --detach

# List what's available and what's running
tmux-ws list

# Tear down a session
tmux-ws kill project
```

## Config

Workspace configs live in `~/.config/tmux-ws/`. Each workspace is a directory with a `workspace.conf` file and optional `hooks/` directory.

```
~/.config/tmux-ws/
├── _templates/
│   └── default.conf          # Base template inherited by workspaces
├── _examples/
│   ├── workspace.conf        # Example config
│   └── hooks/
│       ├── pre-create.sh
│       └── post-create.sh
├── project/
│   ├── workspace.conf
│   └── hooks/
│       ├── pre-create.sh
│       └── post-create.sh
└── myproject/
    ├── workspace.conf
    └── hooks/
        └── post-create.sh
```

### workspace.conf

**Warning:** Config files are executed as shell code. Only use configs you trust.

```bash
# Inherit from a base template (optional)
_BASE="default"

# Default working directory for windows that don't specify one
DEFAULT_DIR="$HOME/projects/myapp"

# Windows to create. Format: "name:directory:command"
# - name:    tab label in tmux
# - dir:     working directory (leave empty for DEFAULT_DIR)
# - command: command to run (leave empty for a shell)
WINDOWS=(
    "editor::vim"
    "server::npm run dev"
    "logs::tail -f /var/log/app.log"
    "shell::"
)
```

### Inheritance

Set `_BASE="default"` to inherit from `~/.config/tmux-ws/_templates/default.conf`. Your workspace config overrides whatever the template defines.

If your workspace doesn't define `WINDOWS`, it inherits the template's windows. If it does define `WINDOWS`, the template's are ignored.

### Hooks

Create `hooks/pre-create.sh` and/or `hooks/post-create.sh` in your workspace directory. They run before and after the tmux session is created.

```bash
#!/bin/bash
# hooks/pre-create.sh
# Runs before tmux session exists. Use for setup tasks.

echo "Starting docker containers..."
docker compose up -d
```

```bash
#!/bin/bash
# hooks/post-create.sh
# Runs after tmux session is created. Use for post-setup tasks.

echo "Waiting for server..."
sleep 3
echo "Ready!"
```

Hooks run in a subshell, so they cannot modify the script's state (WINDOWS, DEFAULT_DIR, etc.). If a hook exits with a non-zero status, workspace creation fails and the hook error is reported.

## Creating a New Workspace

Copy an existing workspace or the example:

```bash
# From the example
cp -r ~/.config/tmux-ws/_examples ~/.config/tmux-ws/myproject

# From an existing workspace
cp -r ~/.config/tmux-ws/project ~/.config/tmux-ws/myproject

# Edit it
tmux-ws edit myproject
```

Directories starting with `_` (like `_templates`, `_examples`) are hidden from `tmux-ws list` but still usable with `tmux-ws create`.

## Testing

```bash
make test          # run test suite
make test-verbose  # run with trace output
```

Requires [bats](https://github.com/bats-core/bats-core). Tests cover: help, version, list, create, inheritance, hooks, validation, kill, edit, and init.

## tmux Configuration

If you're an old fuddy-duddy, like me, who holds on to screen with a death lock grip, you can use tmux-ws with screen-like keybindings.

Add to `~/.tmux.conf`:

```
# screen-like prefix
unbind C-b
set -g prefix C-a
bind C-a send-prefix

# screen-like keybindings
bind A command-prompt "rename-window '%%'"
bind S split-window -v
bind | split-window -h
bind k confirm-before -p "Kill window? (y/n)" kill-window
```

Then reload: `tmux source-file ~/.tmux.conf`

### Keybinding Reference

| Action | Screen | tmux (with config above) |
|---|---|---|
| New window | `Ctrl-a c` | `Ctrl-a c` |
| Next window | `Ctrl-a n` | `Ctrl-a n` |
| Previous window | `Ctrl-a p` | `Ctrl-a p` |
| Jump to window # | `Ctrl-a 0-9` | `Ctrl-a 0-9` |
| Detach | `Ctrl-a d` | `Ctrl-a d` |
| Window list | `Ctrl-a w` | `Ctrl-a w` |
| Rename window | `Ctrl-a A` | `Ctrl-a A` |
| Paste | `Ctrl-a ]` | `Ctrl-a ]` |
| Split horizontal | `Ctrl-a S` | `Ctrl-a S` |
| Split vertical | N/A | `Ctrl-a \|` |
| Kill window | `Ctrl-a k` | `Ctrl-a k` |

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `TMUX_WS_CONFIG` | `~/.config/tmux-ws` | Config directory location |

## Init Behavior

`tmux-ws init` creates the config directory structure with a default template and example workspace. It only creates missing directories and files — it will not overwrite existing configs. If the config directory already exists, it prints a warning and does nothing.

## Files

```
bin/tmux-ws              Main script (add to PATH)
config/                  Default config files
├── _templates/
│   └── default.conf     Base template
└── _examples/
    ├── workspace.conf   Example workspace
    └── hooks/           Example hooks
install.sh               Installation script
```
