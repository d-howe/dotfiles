# Powerlevel10k user configuration is intentionally machine-local.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

alias ll='ls -larthS'
alias dev='cd ~/dev'
alias gbpurge="git branch | grep -v '^\*\|main$' | xargs git branch -d -f"
alias gc="git branch --merged | grep -v '^\*\|main$' | xargs git branch -d -f"
alias grhu='git reset --hard @{u}'
alias gl='git log --graph --abbrev-commit --oneline'
alias gd='git diff main..HEAD'

alias ta='tmux attach -t'
alias tn='tmux new -s'
alias td='tmux kill-session -t'

# Create an idempotent development session with Neovim and an AI agent.
mux() {
  local session_name="${1:-dev}"
  local session_dir="${2:-$PWD}"
  local ai_cmd

  if [[ ! -d "$session_dir" ]]; then
    print -u2 "mux: directory does not exist: $session_dir"
    return 1
  fi

  if command -v cursor-agent >/dev/null 2>&1; then
    ai_cmd="cursor-agent"
  elif command -v claude >/dev/null 2>&1; then
    ai_cmd="claude"
  else
    print -u2 "mux: no supported AI CLI found"
    return 1
  fi

  if ! tmux has-session -t "=${session_name}" 2>/dev/null; then
    tmux new-session -d -s "$session_name" -n main -c "$session_dir"
    tmux send-keys -t "${session_name}:main.1" nvim C-m
    tmux split-window -h -p 40 -t "${session_name}:main.1" -c "$session_dir"
    tmux send-keys -t "${session_name}:main.2" "$ai_cmd" C-m
    tmux select-pane -t "${session_name}:main.1"
  fi

  if [[ -n "$TMUX" ]]; then
    tmux switch-client -t "=${session_name}"
  else
    tmux attach-session -t "=${session_name}"
  fi
}

# Load local, machine-specific configuration last.
if [[ -f "$HOME/.zshrc.local" ]]; then
  source "$HOME/.zshrc.local"
fi
