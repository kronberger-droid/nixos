zoxide init nushell | save -f ~/.zoxide.nu

$env.__zoxide_hooked = true

$env.SSH_AUTH_SOCK = $"($env.XDG_RUNTIME_DIR)/ssh-agent.socket"
