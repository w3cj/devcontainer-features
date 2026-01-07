#!/bin/bash
# Firewall verbose notification hooks
# Displays blocked connection notifications at shell prompt

export FIREWALL_VERBOSE="${FIREWALL_VERBOSE:-true}"

__firewall_display_blocks() {
    [ "$FIREWALL_VERBOSE" != "true" ] && return

    local firewall_tmp="/var/run/firewall"
    local queue_file="$firewall_tmp/display-queue"
    local lock_file="$firewall_tmp/queue.lock"

    [ ! -f "$queue_file" ] && return
    [ ! -s "$queue_file" ] && return

    # Read and clear queue atomically
    (
        flock -w 1 200 || exit 1
        if [ -s "$queue_file" ]; then
            cat "$queue_file"
            : > "$queue_file"
        fi
    ) 200>"$lock_file" | while IFS= read -r msg; do
        # Display in yellow/orange color
        printf '\033[1;33m%s\033[0m\n' "$msg" >&2
    done
}

# Set up hook based on shell
case "${0##*/}" in
    bash|-bash)
        # Bash: use PROMPT_COMMAND
        if [[ ! "${PROMPT_COMMAND:-}" =~ __firewall_display_blocks ]]; then
            PROMPT_COMMAND="__firewall_display_blocks${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
        fi
        ;;
    zsh|-zsh)
        # Zsh: use precmd hook
        autoload -Uz add-zsh-hook 2>/dev/null || true
        if type add-zsh-hook &>/dev/null; then
            add-zsh-hook precmd __firewall_display_blocks
        else
            # Fallback: direct precmd
            precmd_functions+=(__firewall_display_blocks)
        fi
        ;;
esac
