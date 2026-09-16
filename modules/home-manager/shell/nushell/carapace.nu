# Carapace as the external completer, written against nushell's named
# completer inputs.
#
# home-manager's carapace integration sources what `carapace _carapace nushell`
# prints, and that snippet still declares the legacy `{|spans| ...}` closure, so
# on main (nushell#18791) every completion trips the "Positional completer input
# deprecated" warning. The named inputs that replaced it are `token`, `place`
# and `buffer`, and none of them is the old token list: `buffer` is the whole
# line up to the cursor, so the `split row " "` migration upstream suggests
# hands carapace the wrong command after a `|`, `;`, `(` or `{`
# (nushell#19016). `carapace-words` rebuilds the list from the parser's view of
# the buffer instead. Drop it for a `tokens` input once the engine grows one.

# The words of the call the cursor is in, in the shape the old `spans` had:
# the head first, and a trailing "" when the cursor sits on a fresh argument.
def carapace-words [token: record, buffer: string]: nothing -> list<string> {
	# Nesting comes out of the parser as tokens of these kinds, with the bracket
	# itself in `content`.
	const bracketed = [shape_block shape_closure shape_list shape_record shape_table]
	const heads = [shape_external shape_internalcall]

	# Walk back from the cursor. `depth` counts the closed groups we are inside,
	# `words` grows at the front: each is a byte range into the buffer, or the
	# text of an alias-expanded token, which has no place on the line.
	let walk = ast --flatten $buffer | uniq | reverse | reduce --fold {depth: 0, words: [], done: false} {|t, acc|
		if $acc.done {
			$acc
		} else {
			let chars = if $t.shape in $bracketed { $t.content | split chars } else { [] }
			let opens = $chars | where $it in ['(' '[' '{'] | length
			let closes = $chars | where $it in [')' ']' '}'] | length
			# Read backwards, a closing bracket takes us into a group and an
			# opening one out.
			let depth = $acc.depth + $closes - $opens

			if $acc.depth > 0 {
				# Inside a closed group: its opening bracket folds the whole
				# group into the word its closing bracket started.
				if $depth <= 0 {
					{depth: 0, words: ($acc.words | update 0.start ([$t.span.start $acc.words.0.start] | math min)), done: false}
				} else {
					$acc | update depth $depth
				}
			} else if $depth < 0 or $t.shape == shape_pipe {
				# An unmatched opening bracket or a pipe: the cursor's call
				# starts after it, and its head was already seen.
				$acc | update done true
			} else {
				let words = if $t.span.start == $t.span.end {
					$acc.words | prepend {start: 0, end: 0, text: $t.content}
				} else if ($acc.words | is-not-empty) and $acc.words.0.text == null and $t.span.end >= $acc.words.0.start {
					# Touching (or, for the parser's stray re-emissions,
					# overlapping) the word in front: one word, not two.
					$acc.words | update 0.start ([$t.span.start $acc.words.0.start] | math min)
				} else {
					$acc.words | prepend {start: $t.span.start, end: $t.span.end, text: null}
				}
				{depth: $depth, words: $words, done: ($depth == 0 and $t.shape in $heads)}
			}
		}
	}

	let words = $walk.words | each {|w|
		if $w.text != null { $w.text } else { $buffer | str substring $w.start..<$w.end }
	}
	if $token.text == "" { $words | append "" } else { $words }
}

$env.config.completions.external.enable = true
$env.config.completions.external.completer = {|token, place, buffer|
	# Command names are nushell's own to complete.
	if $place.kind == "command" { return null }

	let words = carapace-words $token $buffer
	with-env {
		CARAPACE_SHELL: 'nushell'
		CARAPACE_SHELL_ALIASES: (scope aliases | get name | uniq | str join "\n")
		CARAPACE_SHELL_BUILTINS: (help commands | where category != "" | get name | each { split row " " | first } | uniq | str join "\n")
		CARAPACE_SHELL_FUNCTIONS: (help commands | where category == "" | get name | each { split row " " | first } | uniq | str join "\n")
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
