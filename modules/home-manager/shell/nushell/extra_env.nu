# SSH agent socket (oo7-ssh-agent via systemd socket activation). Only wire it
# up where a runtime dir exists: reading `$env.XDG_RUNTIME_DIR` with the plain
# `$env.NAME` form is a hard error in nushell when the var is unset, and hosts
# without a systemd user session (nix-on-droid/Android) don't set it — that
# error aborts env.nu at every startup, so the nushell login shell never comes
# up. Guard with the optional `?` cell-path so those hosts just skip it.
#
# Also guard on the socket actually being there. This file is shared with
# the homeserver, which runs no keyring: pointing SSH_AUTH_SOCK at a socket
# that never exists there clobbered `ssh -A` forwarding from the laptops on
# every login.
if ($env.XDG_RUNTIME_DIR? | is-not-empty) {
    let sock = $"($env.XDG_RUNTIME_DIR)/oo7-ssh-agent.sock"
    if ($sock | path exists) {
        $env.SSH_AUTH_SOCK = $sock
    }
}

# Force TTY passphrase prompts; suppress OpenSSH's bundled GUI askpass fallback
$env.SSH_ASKPASS_REQUIRE = "never"

# Use skim instead of fzf for navi
$env.NAVI_FINDER = "skim"

# Add ~/.local/bin to PATH
$env.PATH = ($env.PATH | prepend ($env.HOME | path join ".local" "bin"))

# Load GitHub tokens from agenix secrets, into $var if this account may read
# $file. The read itself is the test: `path exists` says yes for every account,
# since /run/agenix is world-traversable and only the owner can open what is
# inside, and this file is shared with the sandbox user (agent-sandbox.nix),
# whose shell would otherwise die on the primary user's 0400 files at startup.
def --env load-secret [file: string, var: string] {
    let value = try { open $file | str trim } catch { null }
    if $value != null {
        load-env { $var: $value }
    }
}

# Two separate tokens for the primary user on purpose, so the scope sets stay
# independent.
#
# GITHUB_PERSONAL_ACCESS_TOKEN feeds the Claude Code GitHub plugin. `gh`
# resolves GH_TOKEN ahead of ~/.config/gh/hosts.yml, so setting it here also
# means `gh auth login` is never needed — which matters, since that flow would
# try to write ~/.config/gh/config.yml, a read-only home-manager store symlink.
# Note this covers every `gh` invocation, not only gh-dash.
load-secret /run/secrets/github-token GITHUB_PERSONAL_ACCESS_TOKEN
load-secret /run/secrets/gh-dash-token GH_TOKEN

# The sandbox account holds one fine-grained token for both jobs; only it can
# read this file, so on the primary user's side both lines are no-ops.
load-secret /run/secrets/claude-github-token GITHUB_PERSONAL_ACCESS_TOKEN
load-secret /run/secrets/claude-github-token GH_TOKEN
