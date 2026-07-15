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
  local requested_agent="${3:-${MUX_AGENT:-}}"
  local ai_cmd
  local editor_pane
  local agent_pane
  local explicit_agent=0

  if tmux has-session -t "=${session_name}" 2>/dev/null; then
    if [[ -n "$TMUX" ]]; then
      tmux switch-client -t "=${session_name}"
    else
      tmux attach-session -t "=${session_name}"
    fi
    return
  fi

  if [[ ! -d "$session_dir" ]]; then
    print -u2 "mux: directory does not exist: $session_dir"
    return 1
  fi

  if [[ -n "$requested_agent" ]]; then
    explicit_agent=1
    case "$requested_agent" in
      cursor-agent | opencode | claude) ai_cmd="$requested_agent" ;;
      *)
        print -u2 "mux: unsupported agent: $requested_agent"
        print -u2 "mux: choose cursor-agent, opencode, or claude"
        return 1
        ;;
    esac
  fi

  if (( explicit_agent )); then
    if ! command -v "$ai_cmd" >/dev/null 2>&1; then
      print -u2 "mux: requested agent is not installed: $ai_cmd"
      return 1
    fi
  else
    local candidate
    for candidate in cursor-agent opencode claude; do
      if command -v "$candidate" >/dev/null 2>&1; then
        ai_cmd="$candidate"
        break
      fi
    done
    if [[ -z "$ai_cmd" ]]; then
      print -u2 "mux: no supported AI CLI found"
      return 1
    fi
  fi

  editor_pane="$(tmux new-session -d -P -F '#{pane_id}' -s "$session_name" -n main -c "$session_dir")" || return
  if ! tmux send-keys -t "$editor_pane" nvim C-m; then
    tmux kill-session -t "=${session_name}"
    return 1
  fi

  agent_pane="$(tmux split-window -h -p 40 -P -F '#{pane_id}' -t "$editor_pane" -c "$session_dir")" || {
    tmux kill-session -t "=${session_name}"
    return 1
  }
  if ! tmux send-keys -t "$agent_pane" "$ai_cmd" C-m; then
    tmux kill-session -t "=${session_name}"
    return 1
  fi
  tmux select-pane -t "$editor_pane"

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
