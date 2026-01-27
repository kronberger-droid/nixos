source ~/.zoxide.nu

# Import modular configuration files
source ~/.config/nushell/development.nu
source ~/.config/nixos/modules/home-manager/nushell/utilities.nu
source ~/.config/nixos/modules/home-manager/nushell/keybindings.nu

$env.config = {
	show_banner: false
	edit_mode: 'vi'
	keybindings: (get_keybindings)
}
