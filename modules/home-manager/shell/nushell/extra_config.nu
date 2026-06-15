# Import modular configuration files
source ~/.config/nushell/utilities.nu
source ~/.config/nushell/keybindings.nu

$env.config = {
	show_banner: false
	edit_mode: 'helix'
	buffer_editor: 'hx'
	shell_integration: {
		osc133: true
		osc633: true
		reset_application_mode: true
	}
	keybindings: (get_keybindings)
}

# Two-line prompt: Starship renders the module row (format = "$all"), then these
# vi-mode indicators drop the cursor to the line below. The leading "\n" is the
# trick — reedline trims a trailing newline off the prompt but keeps a leading
# one on the indicator. The glyph also signals the active vi mode.
$env.PROMPT_INDICATOR_VI_INSERT = "\n: "
$env.PROMPT_INDICATOR_VI_NORMAL = "\n> "
