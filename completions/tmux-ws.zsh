#compdef tmux-ws

# Zsh completion for tmux-ws

_tmux_ws() {
    local config_dir="${TMUX_WS_CONFIG:-$HOME/.config/tmux-ws}"
    local subcommands=(create attach list kill edit init help version)

    _arguments -C \
        '1:subcommand:->subcommand' \
        '2:workspace:->workspace' \
        && return

    case $state in
        subcommand)
            compadd -a subcommands
            ;;
        workspace)
            case $words[2] in
                create|attach|kill|edit)
                    local -a workspaces
                    for dir in "$config_dir"/*/; do
                        [[ ! -f "$dir/workspace.conf" ]] && continue
                        local name="${dir:t}"
                        [[ "$name" == _* ]] && continue
                        workspaces+=("$name")
                    done
                    compadd -a workspaces
                    ;;
            esac
            ;;
    esac
}

_tmux_ws "$@"
