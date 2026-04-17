# Import modular configuration files
source ~/.config/nushell/utilities.nu
source ~/.config/nushell/keybindings.nu

$env.config = {
	show_banner: false
	edit_mode: 'vi'
	shell_integration: {
		osc133: true
		osc633: true
		reset_application_mode: true
	}
	keybindings: (get_keybindings)
}
