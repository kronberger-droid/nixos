# Carapace as the external completer, written against nushell's named
# completer inputs.
#
# home-manager's carapace integration sources what `carapace _carapace nushell`
# prints, and that snippet still declares the legacy `{|spans| ...}` closure, so
# on main (nushell#18791) every completion trips the "Positional completer input
# deprecated" warning. `$place.command` (nushell#19054, aliases expanded by
# #19085) is the argv of the call the cursor is in, with a trailing "" on a
# fresh argument, which is the shape carapace wants even after a `|`, `;`, `(`
# or `{`.

$env.config.completions.external.enable = true
$env.config.completions.external.completer = {|place|
	# Command names are nushell's own to complete.
	if $place.kind == "command" { return null }

	# One `help commands` for both lists; it is most of the cost of a Tab.
	let commands = help commands | select name category | update name { split row " " | first }
	let builtins = $commands | where category != "" | get name | uniq
	let functions = $commands | where category == "" | get name | uniq
	let words = $place.command
	with-env {
		CARAPACE_SHELL: 'nushell'
		CARAPACE_SHELL_ALIASES: (scope aliases | get name | uniq | str join "\n")
		CARAPACE_SHELL_BUILTINS: ($builtins | str join "\n")
		CARAPACE_SHELL_FUNCTIONS: ($functions | str join "\n")
		CARAPACE_SHELL_VARIABLES: (scope variables | get name | uniq | str join "\n")
	} {
		# Carapace answers a position it has no spec for with `[]`, and nushell
		# reads a list, empty or not, as the authoritative set of completions for
		# the slot: `dispatch_external_arg` in nu-cli/src/completions/completer.rs
		# adds its file fallback only where the completer left the slot open, and
		# since nushell#18791 that means returning `null`. Map the empty answer
		# back to `null` so paths still complete where carapace knows nothing, as
		# after the `--` in `cargo run --bin foo -- summary <file>`.
		let result = carapace $words.0 nushell ...$words | from json
		if ($result | is-empty) { null } else { $result }
	}
}
