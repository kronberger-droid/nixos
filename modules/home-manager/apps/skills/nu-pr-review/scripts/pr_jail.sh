#!/usr/bin/env bash
# Run a command that executes PR code (cargo build, test or clippy, the built nu) with nothing worth stealing in reach.
# usage: pr_jail.sh [--net] <command>...
# A PR's build.rs, proc macros and tests are a stranger's code. Here they see the filesystem as it is, minus the
# ssh key, the Claude and gh logins and the decrypted secrets, with the token variables unset and, unless --net
# is given, no network to send anything over. Not a full sandbox: the checkout and the rest of $HOME stay writable.
set -euo pipefail
net=(--unshare-net)
if [ "${1:-}" = --net ]; then net=(); shift; fi
[ $# -gt 0 ] || { echo "usage: pr_jail.sh [--net] <command>..." >&2; exit 2; }
hide=()
for p in "$HOME/.ssh" "$HOME/.gnupg" "$HOME/.claude" "$HOME/.config/gh" /run/secrets /run/claude-sandbox; do
  [ -d "$p" ] && hide+=(--tmpfs "$p")
done
[ -f "$HOME/.claude.json" ] && hide+=(--ro-bind /dev/null "$HOME/.claude.json")
exec env -u GH_TOKEN -u GITHUB_TOKEN -u GITHUB_PERSONAL_ACCESS_TOKEN -u CLAUDE_CODE_OAUTH_TOKEN -u ANTHROPIC_API_KEY \
  bwrap --dev-bind / / "${hide[@]}" "${net[@]}" --die-with-parent -- "$@"
