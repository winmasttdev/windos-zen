#=============================================================================
# windOS Zen — .zshrc  (lives in /etc/skel, copied to every new user + root)
# Goals: blazing fast, beautiful, and optimized for low-spec hardware.
#=============================================================================

# --- paths & caches --------------------------------------------------------
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export ZSH_CACHE_DIR="$XDG_CACHE_HOME/zsh"
mkdir -p "$ZSH_CACHE_DIR"

# history (optimized: dedupe, share, large but bounded)
export HISTSIZE=2000
export SAVEHIST=2000
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt SHARE_HISTORY
setopt EXTENDED_HISTORY

# --- sane zsh options ------------------------------------------------------
setopt autocd
setopt notify
setopt interactive_comments
setopt complete_in_word
setopt always_to_end
bindkey -e                      # emacs-style line editing

# --- completion (fast) -----------------------------------------------------
autoload -Uz compinit
compinit -d "$ZSH_CACHE_DIR/zcompdump-$ZSH_VERSION"
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$ZSH_CACHE_DIR"

# --- plugins (Arch paths) --------------------------------------------------
for p in zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search; do
    f="/usr/share/zsh/plugins/$p/$p.zsh"
    [[ -f "$f" ]] && source "$f"
done
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#5b6b8c"
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)

# --- prompt: Starship (windOS preset) -------------------------------------
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
else
    PS1='%B%F{cyan}➜ %F{blue}%~ %f%b%# '
fi

# --- handy aliases ---------------------------------------------------------
alias ll='ls -lah --color=auto'
alias l='ls -l --color=auto'
alias ..='cd ..'
alias grep='grep --color=auto'
alias fetch='windfetch'
# neofetch was dropped from the repos; use fastfetch (windOS preset) instead.
alias neofetch='fastfetch --config $XDG_CONFIG_HOME/fastfetch/config.jsonc'
alias upd='sudo pacman -Syu'
alias clr='clear && windfetch'

# --- welcome fetch on interactive login ------------------------------------
if [[ $- == *i* ]] && [[ -z "$WINDOS_NO_FETCH" ]]; then
    command -v windfetch >/dev/null 2>&1 && windfetch
fi

# --- secret egg ------------------------------------------------------------
# Not in the manual. We paused the optimization to make tea. You're welcome.
alias tea='sweet-tea'
