# Import modular configuration files
source ~/.config/nushell/utilities.nu
source ~/.config/nushell/keybindings.nu

$env.config = {
	show_banner: false
	# edit_mode + helix cursor shapes are injected after this record by
	# nushell.nix, conditional on the nushell build: the helix edit-mode only
	# exists in our fork (reedline HelixMode), so stock-nushell hosts (mediaBox)
	# fall back to vi and never see the unsupported 'helix' value.
	buffer_editor: 'hx'
	# Cursor per mode (stock-valid keys only; helix_* added by the injection).
	cursor_shape: {
		vi_insert: line
		vi_normal: block
		emacs: line
	}
	# No `color_config` key: the selection colors are generated from the base16
	# scheme and layered on after this record by nushell.nix, since a static
	# .nu file can't interpolate config.scheme.
	shell_integration: {
		osc133: true
		osc633: true
		reset_application_mode: true
	}
	keybindings: (get_keybindings)
	# No `menus` key: the newline that makes the prompt two lines now lives on
	# PROMPT_COMMAND (see nushell.nix), so the completion menus no longer need a
	# hand-copied definition just to prefix their marker with "\n". Omitting them
	# lets nushell inject DEFAULT_COMPLETION_MENU / DEFAULT_IDE_COMPLETION_MENU
	# verbatim, which is what we were mirroring anyway.
}

# Two-line prompt: Starship renders the module row (format = "$all") and the
# PROMPT_COMMAND wrapper in nushell.nix appends the newline, so the indicators
# are just the glyph signalling the active vi mode. Keeping the newline out of
# them matters since reedline swaps the indicator out for the reverse-search
# prompt and completion-menu markers, both of which nushell hardcodes without
# one; with the newline here those would render on the Starship row.
$env.PROMPT_INDICATOR_VI_INSERT = ": "
$env.PROMPT_INDICATOR_VI_NORMAL = "> "
