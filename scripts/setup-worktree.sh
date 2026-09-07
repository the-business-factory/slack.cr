#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
worktree_root=$(git -C "$script_dir/.." rev-parse --show-toplevel)
# Git lists the main worktree first. Preserve spaces in its path.
main_root=$(git -C "$worktree_root" worktree list --porcelain | sed -n '1s/^worktree //p')
plans_source="$main_root/plans"
plans_target="$worktree_root/plans"

if [[ ! -d "$plans_source" ]]; then
  printf 'Missing main-worktree plans directory: %s\n' "$plans_source" >&2
  exit 1
fi

if [[ "$worktree_root" != "$main_root" ]]; then
  if [[ -L "$plans_target" && "$plans_target" -ef "$plans_source" ]]; then
    printf 'Plans already linked to %s\n' "$plans_source"
  elif [[ -e "$plans_target" || -L "$plans_target" ]]; then
    printf 'Refusing to replace existing plans path: %s\n' "$plans_target" >&2
    exit 1
  else
    ln -s "$plans_source" "$plans_target"
    printf 'Linked plans to %s\n' "$plans_source"
  fi
fi

cd -- "$worktree_root"
shards install
