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

# Load GitHub tokens from agenix secrets. Two separate tokens on purpose, so the
# scope sets stay independent.
if ("/run/secrets/github-token" | path exists) {
    # Claude Code GitHub plugin.
    $env.GITHUB_PERSONAL_ACCESS_TOKEN = (open /run/secrets/github-token | str trim)
}

# `gh` resolves GH_TOKEN ahead of ~/.config/gh/hosts.yml, so setting it here also
# means `gh auth login` is never needed — which matters, since that flow would
# try to write ~/.config/gh/config.yml, a read-only home-manager store symlink.
# Note this covers every `gh` invocation, not only gh-dash.
if ("/run/secrets/gh-dash-token" | path exists) {
    $env.GH_TOKEN = (open /run/secrets/gh-dash-token | str trim)
}
