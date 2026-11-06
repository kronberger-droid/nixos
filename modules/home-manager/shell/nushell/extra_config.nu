# Import modular configuration files
source ~/.config/nushell/utilities.nu

$env.config = {
	show_banner: false
	# Every host runs the upstream-main nushell from the shared overlay, which
	# has the helix edit mode; there is no vi fallback.
	edit_mode: helix
	buffer_editor: 'hx'
	# sqlite keeps cwd, exit status and duration per entry, and lets single
	# entries be removed with `query db "DELETE FROM history WHERE ..."`.
	history: {
		file_format: sqlite
	}
	cursor_shape: {
		vi_insert: line
		vi_normal: block
		emacs: line
		helix_normal: block
		helix_select: underscore
		helix_insert: line
	}
	# No `color_config` key: the selection colors are generated from the base16
	# scheme and layered on after this record by nushell.nix, since a static
	# .nu file can't interpolate config.scheme.
	shell_integration: {
		osc133: true
		osc633: true
		reset_application_mode: true
	}
	# No `keybindings` or `menus` key: assigning either replaces nushell's whole
	# default list (Tab completion included), so keybindings are appended below
	# and the default menus stay untouched.
}

# The status line under the prompt (nushell#19403): keep the errors, drop the
# signature, type and preview, which say little for anything that isn't a builtin.
$env.config.status_line = {enable: true, errors: true, signature: false, type: false, preview: false}

# Starting from the defaults keeps this stable if the file is sourced again.
# The helix_* modes need the upstream-main nushell from the shared overlay.
$env.config.keybindings = (config default).keybindings ++ [{
	name: accept_completion
	modifier: control
	keycode: char_f
	mode: [helix_insert helix_normal vi_insert vi_normal]
	event: { send: HistoryHintComplete }
}]
