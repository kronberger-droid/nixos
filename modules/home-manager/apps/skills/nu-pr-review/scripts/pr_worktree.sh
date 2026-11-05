#!/usr/bin/env bash
# Check out a PR's head in its own worktree and build it, seeding target/debug from main's build first.
# usage: pr_worktree.sh N [nushell/nushell|nushell/nu_scripts]
# Stops without touching anything when the worktree has local changes.
# The worktree goes in the clone's own .claude/worktrees/, where Claude Code keeps its worktrees.
# PR_WORKTREE_ROOT moves it elsewhere. A missing clone is made from upstream first.
set -euo pipefail
N=$1 R=${2:-nushell/nushell}
case $R in
  nushell/nushell) SRC=~/Projects/rust/nushell ;;
  nushell/nu_scripts) SRC=~/Projects/rust/nu_scripts ;;
  *) echo "unknown repo $R" >&2; exit 2 ;;
esac
WT=${PR_WORKTREE_ROOT:-$SRC/.claude/worktrees}/pr_$N

# The clone's remotes are the user's: origin is the fork, upstream is where PRs live.
if [ ! -d "$SRC" ]; then
  git clone -q "https://github.com/$R.git" "$SRC"
  git -C "$SRC" remote rename origin upstream
fi
# Keep the worktrees out of the clone's `git status` without touching its tracked .gitignore.
EXCLUDE=$(git -C "$SRC" rev-parse --path-format=absolute --git-path info/exclude)
grep -qxF '.claude/worktrees/' "$EXCLUDE" 2>/dev/null || { mkdir -p "$(dirname "$EXCLUDE")"; echo '.claude/worktrees/' >> "$EXCLUDE"; }

if [ -d "$WT" ] && [ -n "$(git -C "$WT" status --short)" ]; then
  git -C "$WT" status --short
  echo "STOP: $WT has local changes; ask the user before moving it" >&2
  exit 3
fi
# origin is the user's fork; PRs live on upstream. A named ref, not FETCH_HEAD: code-review's fork
# fetches in the same repo at the same time and would overwrite FETCH_HEAD between two commands.
# --no-prune: with the user's fetch.prune=true, a refetch deletes the ref it was asked to update.
HEAD_REF=refs/pr-heads/$N
git -C "$SRC" fetch -q --no-prune upstream "+refs/pull/$N/head:$HEAD_REF"
if [ -d "$WT" ]; then
  git -C "$WT" checkout -q -B "pr_$N" "$HEAD_REF"
else
  git -C "$SRC" worktree prune
  git -C "$SRC" branch -f "pr_$N" "$HEAD_REF"
  git -C "$SRC" worktree add -q "$WT" "pr_$N"
fi
echo "worktree: $WT at $(git -C "$WT" log -1 --format='%h %s')"

BEFORE=$(command -v nu) # the installed nu, which is upstream main (flake input nushell-src)
echo "before: $BEFORE $($BEFORE -n -c 'version | $"($in.version) commit ($in.commit_hash | str substring 0..8)"'), upstream main is $(git -C "$SRC" rev-parse --short=9 upstream/main)"
[ "$R" = nushell/nushell ] || exit 0

if [ ! -d "$WT/target" ]; then
  # Seeding from main's debug dir cuts the build to a few minutes: PRs branch from main, so most of its artifacts match.
  # cp --reflink=auto is a copy-on-write clone on btrfs or xfs and a plain, slower copy elsewhere (ext4).
  # Never seed from a worktree's target. Cargo never prunes deps, so a clone inherits every generation that
  # worktree ever built, and a branch with its own rustflags misses the cache for every crate (850K
  # deps entries, a 32-minute rebuild, 143 GB held by three PR targets).
  SEED=$SRC/target/debug
  echo "disk: $(df -h ~ | awk 'NR==2 {print $4}') free (a seeded build adds about 4 GB)"
  if [ -d "$SEED" ]; then
    mkdir -p "$WT/target"
    cp --reflink=auto -R "$SEED" "$WT/target/debug"
    echo "seeded target/debug from $SEED"
  else
    echo "main has no debug build to seed from: this is a cold build"
  fi
fi
cd "$WT"
unset CARGO_TARGET_DIR
mkdir -p target
if ! cargo build >target/pr_build.log 2>&1; then
  tail -40 target/pr_build.log
  echo "build failed: full log in $WT/target/pr_build.log" >&2
  exit 1
fi
tail -1 target/pr_build.log
# Not `version | get commit_hash`: build.rs doesn't rerun on an incremental build, so it can name an older head.
echo "branch: $WT/target/debug/nu"
