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
	# Visual/select highlight (helix-style gray). Only `bg` is set so selected
	# text keeps its syntax color. Read by the fork's with_visual_selection_style
	# (color_config.selection); other shapes still use nushell defaults.
	color_config: {
		selection: { bg: "#45475a" }
	}
	shell_integration: {
		osc133: true
		osc633: true
		reset_application_mode: true
	}
	keybindings: (get_keybindings)
	# Redefine the default completion menus only to give their marker a leading
	# "\n". reedline swaps this marker in as the prompt indicator while a menu is
	# active; without the newline it collapses our two-line prompt and shifts the
	# buffer. Everything else mirrors nushell's DEFAULT_*_COMPLETION_MENU.
	menus: [
		{
			name: completion_menu
			only_buffer_difference: false
			marker: "\n| "
			type: {
				layout: columnar
				columns: 4
				col_width: 20
				col_padding: 2
				tab_traversal: "horizontal"
			}
			style: {
				text: green
				selected_text: green_reverse
				description_text: yellow
			}
		}
		{
			name: ide_completion_menu
			only_buffer_difference: false
			marker: "\n| "
			type: {
				layout: ide
				min_completion_width: 0
				max_completion_width: 50
				max_completion_height: 10
				padding: 0
				border: true
				cursor_offset: 0
				description_mode: "prefer_right"
				min_description_width: 15
				max_description_width: 50
				max_description_height: 10
				description_offset: 1
				correct_cursor_pos: false
			}
			style: {
				text: green
				selected_text: { attr: r }
				description_text: yellow
				match_text: { attr: u }
				selected_match_text: { attr: ur }
			}
		}
	]
}

# Two-line prompt: Starship renders the module row (format = "$all"), then these
# vi-mode indicators drop the cursor to the line below. The leading "\n" is the
# trick — reedline trims a trailing newline off the prompt but keeps a leading
# one on the indicator. The glyph also signals the active vi mode.
$env.PROMPT_INDICATOR_VI_INSERT = "\n: "
$env.PROMPT_INDICATOR_VI_NORMAL = "\n> "
