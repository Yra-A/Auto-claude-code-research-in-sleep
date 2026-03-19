#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

log() {
  printf '[%s] %s\n' "$SCRIPT_NAME" "$*"
}

warn() {
  printf '[%s] warning: %s\n' "$SCRIPT_NAME" "$*" >&2
}

die() {
  printf '[%s] error: %s\n' "$SCRIPT_NAME" "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage:
  tools/github_fork_sync.sh setup <your-github-repo-url> [official-repo-url]
  tools/github_fork_sync.sh sync [branch]

Workflow:
  1. setup: keep the official repo on `upstream`, point `origin` to your GitHub repo,
     then push the current branch to your repo.
  2. sync:  pull from `upstream/<branch>`, then push to `origin/<branch>`.

Examples:
  tools/github_fork_sync.sh setup https://github.com/yourname/Auto-claude-code-research-in-sleep.git
  tools/github_fork_sync.sh sync
  tools/github_fork_sync.sh sync main
EOF
}

require_git_repo() {
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "${REPO_ROOT:-}" ] || die "current directory is not inside a git repository"
  cd "$REPO_ROOT"
}

remote_exists() {
  git remote get-url "$1" >/dev/null 2>&1
}

current_branch() {
  git branch --show-current 2>/dev/null || true
}

git_is_dirty() {
  [ -n "$(git status --porcelain)" ]
}

canonical_remote() {
  local url="$1"

  case "$url" in
    git@github.com:*)
      url="${url#git@github.com:}"
      ;;
    ssh://git@github.com/*)
      url="${url#ssh://git@github.com/}"
      ;;
    https://github.com/*)
      url="${url#https://github.com/}"
      ;;
    http://github.com/*)
      url="${url#http://github.com/}"
      ;;
  esac

  printf '%s\n' "${url%.git}"
}

same_remote() {
  [ "$(canonical_remote "$1")" = "$(canonical_remote "$2")" ]
}

setup_cmd() {
  local fork_url="${1:-}"
  local upstream_url="${2:-}"
  local branch=""
  local current_origin=""

  [ -n "$fork_url" ] || die "missing your GitHub repo URL"

  require_git_repo

  branch="$(current_branch)"
  [ -n "$branch" ] || die "detached HEAD is not supported; switch to a branch first"

  current_origin="$(git remote get-url origin 2>/dev/null || true)"

  if [ -z "$upstream_url" ]; then
    if remote_exists upstream; then
      upstream_url="$(git remote get-url upstream)"
    elif [ -n "$current_origin" ] && ! same_remote "$current_origin" "$fork_url"; then
      upstream_url="$current_origin"
    else
      die "cannot infer official repo URL; pass it as the second argument"
    fi
  fi

  if remote_exists upstream; then
    if ! same_remote "$(git remote get-url upstream)" "$upstream_url"; then
      log "Updating upstream -> $upstream_url"
      git remote set-url upstream "$upstream_url"
    fi
  else
    if [ -n "$current_origin" ] && same_remote "$current_origin" "$upstream_url" && ! same_remote "$current_origin" "$fork_url"; then
      log "Renaming origin to upstream"
      git remote rename origin upstream
    else
      log "Adding upstream -> $upstream_url"
      git remote add upstream "$upstream_url"
    fi
  fi

  if remote_exists origin; then
    if ! same_remote "$(git remote get-url origin)" "$fork_url"; then
      log "Updating origin -> $fork_url"
      git remote set-url origin "$fork_url"
    fi
  else
    log "Adding origin -> $fork_url"
    git remote add origin "$fork_url"
  fi

  if git_is_dirty; then
    warn "you have uncommitted changes. They will not be included in the push."
  fi

  log "Pushing $branch to origin"
  git push -u origin "$branch"

  log "Done. Current remotes:"
  git remote -v
}

sync_cmd() {
  local branch="${1:-}"

  require_git_repo

  remote_exists origin || die "origin remote is missing; run setup first"
  remote_exists upstream || die "upstream remote is missing; run setup first"

  branch="${branch:-$(current_branch)}"
  [ -n "$branch" ] || die "cannot determine branch"

  if git_is_dirty; then
    die "working tree is not clean. Commit or stash your changes before syncing."
  fi

  if [ "$(current_branch)" != "$branch" ]; then
    git switch "$branch"
  fi

  log "Fetching upstream"
  git fetch upstream

  git show-ref --verify --quiet "refs/remotes/upstream/$branch" || die "upstream branch does not exist: upstream/$branch"

  log "Pulling upstream/$branch into $branch"
  git pull --no-rebase upstream "$branch"

  log "Pushing $branch to origin"
  git push origin "$branch"
}

main() {
  case "${1:-}" in
    setup)
      shift
      setup_cmd "$@"
      ;;
    sync)
      shift
      sync_cmd "$@"
      ;;
    -h|--help|help|"")
      usage
      ;;
    *)
      die "unknown subcommand: ${1:-}"
      ;;
  esac
}

main "$@"
