#!/bin/bash
# Bash completion for tmux-ws

_tmux_ws() {
    local config_dir="${TMUX_WS_CONFIG:-$HOME/.config/tmux-ws}"
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    local subcommands="create attach list kill edit init help version"

    # First argument: complete subcommands
    if [[ $COMP_CWORD -eq 1 ]]; then
        COMPREPLY=($(compgen -W "$subcommands" -- "$cur"))
        return
    fi

    # Second argument: complete workspace names for commands that take them
    if [[ $COMP_CWORD -eq 2 ]]; then
        case "$prev" in
            create|attach|kill|edit)
                local workspaces=""
                for dir in "$config_dir"/*/; do
                    [[ ! -f "$dir/workspace.conf" ]] && continue
                    local name
                    name=$(basename "$dir")
                    [[ "$name" == _* ]] && continue
                    workspaces="$workspaces $name"
                done
                COMPREPLY=($(compgen -W "$workspaces" -- "$cur"))
                ;;
        esac
    fi
}

complete -F _tmux_ws tmux-ws
