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

# Add ~/.local/bin to PATH
$env.PATH = ($env.PATH | prepend ($env.HOME | path join ".local" "bin"))

# Load GitHub tokens from agenix secrets, into $var if this account may read
# $file. The read itself is the test: `path exists` says yes for every account,
# since /run/agenix is world-traversable and only the owner can open what is
# inside, and this file is shared with the sandbox user (agent-sandbox.nix),
# whose shell would otherwise die on the primary user's 0400 files at startup.
def --env load-secret [file: string, ...vars: string] {
    let value = try { open $file | str trim } catch { null }
    if $value != null {
        load-env ($vars | each {|var| { $var: $value } } | into record)
    }
}

# The primary user's GitHub token is not exported here. The login shell's
# environment becomes the session's, and from there every app's, the
# sandboxed ones included: a token in it is readable by any of them. `gh`
# and `gh-dash` read theirs at call time instead (shell/git.nix).
#
# The sandbox account holds one fine-grained token for both jobs; only it can
# read these files, so on the primary user's side the lines are no-ops, and
# its session runs no sandboxed apps that would inherit the value. The
# workstations keep it in /run/secrets. The homeserver hands it out only
# while a Remote Control window is open (claude-sandbox-open), at the second
# path, which is gone again when the window closes.
load-secret /run/secrets/claude-github-token GITHUB_PERSONAL_ACCESS_TOKEN GH_TOKEN
load-secret /run/claude-sandbox/github-token GITHUB_PERSONAL_ACCESS_TOKEN GH_TOKEN
