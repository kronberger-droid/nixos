# ~/.config/nushell/env.nu
#
# Generate starship's nushell integration once per startup, so the init script
# always matches the installed starship version.

mkdir ($nu.data-dir | path join "vendor/autoload")
starship init nu | save -f ($nu.data-dir | path join "vendor/autoload/starship.nu")
