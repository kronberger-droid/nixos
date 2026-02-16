zoxide init nushell | save -f ~/.zoxide.nu

$env.__zoxide_hooked = true

$env.SSH_AUTH_SOCK = "/run/user/1000/gcr/ssh"

# Add ~/.local/bin to PATH
$env.PATH = ($env.PATH | prepend ($env.HOME | path join ".local" "bin"))

# Load GitHub token from agenix secret (for Claude Code GitHub plugin)
if ("/run/secrets/github-token" | path exists) {
    $env.GITHUB_PERSONAL_ACCESS_TOKEN = (open /run/secrets/github-token | str trim)
}
