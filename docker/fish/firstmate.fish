# Firstmate Homelab interactive Fish configuration.
# This file lives in the image so the defaults remain reproducible across rebuilds.

if status is-interactive
    # Keep user-installed tools first.
    fish_add_path -g $HOME/.local/bin

    # Debian ships bat/fd with names that avoid collisions. Prefer the ergonomic names.
    if command -q batcat
        alias bat='batcat'
    end
    if command -q fdfind
        alias fd='fdfind'
    end

    # Safer, more useful defaults.
    alias ll='ls -lah --group-directories-first'
    alias la='ls -A'
    alias l='ls -CF'
    alias grep='grep --color=auto'
    alias ..='cd ..'
    alias ...='cd ../..'
    alias ....='cd ../../..'

    # Prefer modern directory listings when available while leaving /bin/ls untouched
    # for scripts and compatibility.
    if command -q exa
        alias ls='exa --group-directories-first --icons'
        alias ll='exa -lah --group-directories-first --git --icons'
        alias tree='exa --tree --group-directories-first --icons'
    end

    # Git shortcuts kept intentionally small and unsurprising.
    alias gs='git status --short --branch'
    alias gl='git log --oneline --decorate --graph --all -20'
    alias gd='git diff'
    alias gds='git diff --staged'

    # Fast navigation and fuzzy search.
    if command -q zoxide
        zoxide init fish | source
    end

    if command -q fzf
        set -gx FZF_DEFAULT_OPTS '--height=45% --layout=reverse --border --info=inline --preview-window=right:55%:wrap'
    end

    # A small Matrix-green prompt that stays readable and dependency-free.
    function fish_prompt
        set -l last_status $status
        set -l green (set_color 00ff66)
        set -l muted (set_color 6b7280)
        set -l normal (set_color normal)

        printf '%s%s%s ' $green (prompt_pwd) $normal

        if command -q git
            set -l branch (command git symbolic-ref --quiet --short HEAD 2>/dev/null)
            if test -n "$branch"
                printf '%s(%s)%s ' $muted $branch $normal
            end
        end

        if test $last_status -eq 0
            printf '%s❯%s ' $green $normal
        else
            printf '%s❯%s ' (set_color red) $normal
        end
    end

    # Disable the default greeting; the prompt should stay clean for long sessions.
    set -g fish_greeting
end
