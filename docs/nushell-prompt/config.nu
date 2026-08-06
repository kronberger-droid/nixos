# ~/.config/nushell/config.nu — prompt section
#
# Two-line prompt: Starship renders the module row on line one, nushell renders
# the mode indicator + input on line two.
#
# Starship itself is loaded from `vendor/autoload/starship.nu` (written by
# env.nu). Autoload files run *before* config.nu, so `$env.PROMPT_COMMAND` is
# already Starship's closure by the time this file runs — which is what the
# wrapper at the bottom depends on.

# Vi/Helix mode is what makes the indicators below meaningful. Use 'emacs' and
# `$env.PROMPT_INDICATOR` instead if you don't want modal editing.
$env.config.edit_mode = 'vi'

$env.config.cursor_shape = {
    vi_insert: line
    vi_normal: block
    emacs: line
}

# The mode indicator is *just* the glyph — no leading newline. Reedline swaps
# this indicator out for the reverse-search prompt and the completion-menu
# markers, and nushell hardcodes those two without a newline; putting the
# newline here would leave them rendering on the Starship row instead.
$env.PROMPT_INDICATOR_VI_INSERT = ": "
$env.PROMPT_INDICATOR_VI_NORMAL = "> "

# Move the line break out of Starship and into nushell, so *every* indicator
# reedline can swap in starts on line two.
#
# It has to be appended here rather than via starship's `format`, because
# nushell strips one trailing newline off external command output and would
# eat Starship's own.
#
# Pair this with `line_break.disabled = true` and `character.disabled = true`
# in starship.toml — see the comment on `format` there.
let starship_prompt = $env.PROMPT_COMMAND
$env.PROMPT_COMMAND = {|| (do $starship_prompt) + "\n" }
