# SSH agent socket (oo7-ssh-agent via systemd socket activation). Only wire it
# up where a runtime dir exists: reading `$env.XDG_RUNTIME_DIR` with the plain
# `$env.NAME` form is a hard error in nushell when the var is unset, and hosts
# without a systemd user session (nix-on-droid/Android) don't set it — that
# error aborts env.nu at every startup, so the nushell login shell never comes
# up. Guard with the optional `?` cell-path so those hosts just skip it.
if ($env.XDG_RUNTIME_DIR? | is-not-empty) {
    $env.SSH_AUTH_SOCK = $"($env.XDG_RUNTIME_DIR)/oo7-ssh-agent.sock"
}

# Force TTY passphrase prompts; suppress OpenSSH's bundled GUI askpass fallback
$env.SSH_ASKPASS_REQUIRE = "never"

# Use skim instead of fzf for navi
$env.NAVI_FINDER = "skim"

# Add ~/.local/bin to PATH
$env.PATH = ($env.PATH | prepend ($env.HOME | path join ".local" "bin"))

# Load GitHub token from agenix secret (for Claude Code GitHub plugin)
if ("/run/secrets/github-token" | path exists) {
    $env.GITHUB_PERSONAL_ACCESS_TOKEN = (open /run/secrets/github-token | str trim)
}
