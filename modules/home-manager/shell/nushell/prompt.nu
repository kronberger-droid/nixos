# The prompt, in nushell instead of starship.
#
#     use prompt.nu
#     $env.PROMPT_COMMAND = {|| prompt left }
#
# Everything here runs in-process except git, which is one call to the `gstat`
# plugin: a process that stays up between prompts and keeps the repository
# open. starship cost two spawns per prompt, 12ms outside a repository and
# 20 to 45ms inside one; this is under 1ms outside and 2 to 25ms inside.
#
# `left` and `right` need `gstat`. `transient` does not, so a host without the
# plugin can keep starship for the live prompt and still collapse to this one.
#
# The placeholder constant below is filled in by nushell.nix
# (pkgs.replaceVars).

# Every color is an ANSI name, which the terminal resolves through the scheme.
# The vault, ~-contracted. Shown as "vault" instead of its long path.
const VAULT = "@vault@"

# Nerd font glyphs, the ones starship's nerd-font-symbols preset uses.
const GLYPH = {
    branch: "\u{e725}"
    tag: "\u{f02b}"
    package: "\u{f03d7}"
    rust: "\u{f1617}"
    python: "\u{e235}"
    c: "\u{e61e}"
    cmake: "\u{e794}"
    typst: "\u{f37f}"
    nix: "\u{f313}"
    battery: "\u{f0083}"
    charging: "\u{f0084}"
    jobs: "\u{2726}"
}

# Where the kernel publishes batteries.
const POWER = "/sys/class/power_supply"

# `text` in `style`, or nothing when there is no text, so an absent segment
# drops out of the row instead of leaving a gap.
def paint [style: any, text: string]: nothing -> string {
    if ($text | is-empty) { "" } else { $"(ansi $style)($text)(ansi reset)" }
}

# `3s`, `1m1s`, `1h2m5s`: starship's cmd_duration form.
def clock [ms: int]: nothing -> string {
    let s = $ms // 1000
    [[n unit]; [($s // 3600) h] [(($s mod 3600) // 60) m] [($s mod 60) s]]
    | where n > 0 | each {|p| $"($p.n)($p.unit)" } | str join
}

# "< took 3s" for the last command, from 2s up, the "<" answering the ">" the
# command was typed at. `$env.CMD_DURATION_MS` starts
# out as the string "0823", which is under the threshold like any fast command.
def seg-took []: nothing -> string {
    let ms = ($env.CMD_DURATION_MS? | default "0" | into int)
    if $ms < 2000 { "" } else { "< " + (paint yellow $"took (clock $ms)") }
}

# user@host, only where it is not obvious: over ssh, or as root.
def seg-host []: nothing -> string {
    if ($env.SSH_CONNECTION? | is-empty) and not (is-admin) { return "" }
    (paint yellow_bold $"($env.USER? | default '?')@((sys host).hostname)") + " in"
}

# Where we are: from the repository root down inside one, the ~-contracted
# path elsewhere, the last three parts of either.
def seg-dir [g: record]: nothing -> string {
    let path = ($env.PWD | str replace $nu.home-dir "~" | str replace $VAULT "vault")
    let parts = ($path | path split)
    let from_repo = if $g.repo_name == "no_repository" { $parts } else {
        # gstat names the repository after its working directory, so the last
        # part with that name is its root.
        let root = ($parts | enumerate | where item == $g.repo_name | get -o index | last)
        if $root == null { $parts } else { $parts | skip $root }
    }
    paint cyan_bold ($from_repo | last 3 | path join)
}

# starship's git_status letters, from gstat's counts.
def seg-git-status [g: record]: nothing -> string {
    let flags = [
        [when sym];
        [($g.conflicts > 0) "="]
        [($g.stashes > 0) "$"]
        [(($g.wt_deleted + $g.idx_deleted_staged) > 0) "✘"]
        [(($g.wt_renamed + $g.idx_renamed) > 0) "»"]
        [($g.wt_modified > 0) "!"]
        [(($g.idx_added_staged + $g.idx_modified_staged) > 0) "+"]
        [($g.wt_untracked > 0) "?"]
        [($g.ahead > 0 and $g.behind > 0) "↕"]
        [($g.ahead > 0 and $g.behind <= 0) "↑"]
        [($g.behind > 0 and $g.ahead <= 0) "↓"]
    ] | where when | get sym | str join
    if ($flags | is-empty) { "" } else { paint red_bold $"[($flags)]" }
}

# Branch, the tag on HEAD, an operation in progress, and the status letters.
def seg-git [g: record]: nothing -> list<string> {
    if $g.repo_name == "no_repository" { return [] }
    let branch = if ($g.branch | str length) > 32 { ($g.branch | str substring 0..<32) + "…" } else { $g.branch }
    # The branch upstream, when it goes by another name: "topic:main".
    let upstream = ($g.remote | split row "/" | skip 1 | str join "/")
    let tracked = if ($upstream | is-empty) or $upstream == $g.branch { "" } else { $":($upstream)" }
    [
        ("on " + (paint purple_bold $"($GLYPH.branch) ($branch)($tracked)"))
        (if $g.tag == "no_tag" { "" } else { paint green $"($GLYPH.tag) ($g.tag)" })
        (if $g.state in ["clean" "no_state" ""] { "" } else { paint yellow_bold ($g.state | str uppercase) })
        (seg-git-status $g)
    ]
}

# The Cargo package version, for release work. `version.workspace = true`
# defers to the workspace table.
def seg-package []: nothing -> string {
    if not ("Cargo.toml" | path exists) { return "" }
    let toml = (try { open Cargo.toml } catch { return "" })
    let own = ($toml | get -o package.version)
    let v = if ($own | describe) == "string" { $own } else { $toml | get -o workspace.package.version }
    if ($v | describe) == "string" { "is " + (paint yellow $"($GLYPH.package) v($v)") } else { "" }
}

# A battery at 10% or less, starship's threshold. It is a warning, so it sits
# in the row that stays. Read from sysfs: a machine without a battery, or
# without sysfs, shows nothing.
def seg-battery []: nothing -> string {
    let battery = (glob $"($POWER)/BAT*" | get -o 0)
    if $battery == null { return "" }
    let level = (try { open --raw ($battery | path join capacity) | str trim | into int } catch { return "" })
    if $level > 10 { return "" }
    let status = (try { open --raw ($battery | path join status) | str trim } catch { "" })
    paint red_bold $"(if $status == Charging { $GLYPH.charging } else { $GLYPH.battery }) ($level)%"
}

# What a prompt starts with: the blank spacer row, with the last command's
# duration in a row of its own above it when there is one. That puts the
# duration right under the output it timed and keeps the row above the prompt
# blank either way. `left` and `transient` both start with this, so the
# duration stays where it is when the prompt collapses. In the right prompt
# it jumped from the input line to here on every submit.
def lead []: nothing -> string {
    let took = (seg-took)
    if ($took | is-empty) { "\n" } else { $"($took)\n\n" }
}

# The module row: what should survive a slim terminal. Leads with the spacer
# row and ends on a newline, so the input starts on a line of its own.
export def left []: nothing -> string {
    # --exact-tag: only a tag on HEAD, without a walk through the history.
    # A failing call (the directory was deleted under the shell, say) must not
    # take the prompt down with it.
    let g = (try { gstat --exact-tag } catch { {repo_name: no_repository} })
    let row = ([(seg-host) (seg-dir $g) ...(seg-git $g) (seg-package) (seg-battery)] | where $it != "" | str join " ")
    $"(lead)($row)\n"
}

# The version `bin` reports, asked once per build of it. A tool on PATH in a
# nix system resolves to a store path, which names one build for good, so the
# answer is cached under that path and later prompts read a file instead of
# spawning the tool. Anything else (a rustup proxy, say) gets no answer here,
# since its version can change behind an unchanged path.
def tool-version [bin: string, args: list<string>, pattern: string]: nothing -> string {
    let path = (which $bin | get -o 0.path | default "" | path expand)
    if not ($path | str starts-with "/nix/store/") { return "" }
    let cache = ($nu.cache-dir | path join prompt $"($bin)-($path | hash md5)")
    if ($cache | path exists) { return (open --raw $cache) }
    let version = (
        do { ^$path ...$args } | complete | get stdout
        | parse --regex $pattern | get -o 0.capture0 | default ""
    )
    mkdir ($cache | path dirname)
    $version | save --force $cache
    $version
}

# One segment per toolchain the directory calls for, by the same files
# starship looks at.
def seg-tools []: nothing -> list<string> {
    let names = (try { ls --all | get name } catch { [] })
    let has = {|files: list<string>, exts: list<string>|
        ($names | any {|n| $n in $files or ($n | path parse | get extension) in $exts })
    }
    let version = '(\d+\.\d+(?:\.\d+)?)'
    [
        (if (do $has [Cargo.toml] [rs]) {
            let v = (tool-version rustc [--version] $version)
            paint red $"($GLYPH.rust) (if ($v | is-empty) { '' } else { $'v($v)' })"
        })
        (if (do $has [pyproject.toml requirements.txt .python-version setup.py] [py]) {
            let v = (tool-version python3 [--version] $version)
            let venv = ($env.VIRTUAL_ENV? | default "" | path basename)
            paint yellow ([$GLYPH.python (if ($v | is-empty) { "" } else { $"v($v)" }) (if ($venv | is-empty) { "" } else { $"\(($venv)\)" })] | where $it != "" | str join " ")
        })
        (if (do $has [] [c h cpp hpp cc]) {
            let v = (tool-version cc [--version] $version)
            paint green $"($GLYPH.c) (if ($v | is-empty) { '' } else { $'v($v)' })"
        })
        (if (do $has [CMakeLists.txt CMakeCache.txt] []) {
            let v = (tool-version cmake [--version] $version)
            paint blue $"($GLYPH.cmake) (if ($v | is-empty) { '' } else { $'v($v)' })"
        })
        (if (do $has [template.typ] [typ]) {
            let v = (tool-version typst [--version] $version)
            paint cyan $"($GLYPH.typst) (if ($v | is-empty) { '' } else { $'v($v)' })"
        })
    ] | compact | each { str trim }
}

# A nix shell: "pure" when it is, and the name the shell goes by.
def seg-nix []: nothing -> string {
    let kind = ($env.IN_NIX_SHELL? | default "")
    if ($kind | is-empty) { return "" }
    paint blue ([$GLYPH.nix (if $kind == "pure" { "pure" } else { "" }) ($env.name? | default "")] | where $it != "" | str join " ")
}

# Background jobs: the mark alone for one, with the count from two, as
# starship has it.
def seg-jobs []: nothing -> string {
    let count = (job list | length)
    if $count == 0 { "" } else { paint blue_bold $"($GLYPH.jobs)(if $count > 1 { $count } else { '' })" }
}

# The right side: what can go when space is tight, the toolchains and the nix
# shell behind one "via", then the jobs. It sits on the input line
# and reedline hides it once the typing reaches it.
export def right []: nothing -> string {
    let via = ([...(seg-tools) (seg-nix)] | where $it != "" | str join " ")
    [(if ($via | is-empty) { "" } else { $"via ($via)" }) (seg-jobs)] | where $it != "" | str join " "
}

# The checkout the directory is in: its branch, or the short hash when HEAD
# is detached, and nothing outside a repository. Read off `.git/HEAD` and
# not asked of gstat, so `transient` keeps working without the plugin and
# pays a few file reads per submit where gstat's status walk costs up to
# 25ms.
def head-name []: nothing -> string {
    let parts = ($env.PWD | path split)
    let dot = (
        ($parts | length)..1
        | each {|n| $parts | first $n | path join | path join .git }
        | where ($it | path exists)
        | get -o 0
    )
    if $dot == null { return "" }
    # In a worktree or a submodule `.git` is a file that names the real
    # directory, relative to itself or absolute.
    let gitdir = if ($dot | path join HEAD | path exists) { $dot } else {
        let target = (try { open --raw $dot | str trim | str replace "gitdir: " "" } catch { return "" })
        $dot | path dirname | path join $target
    }
    let head = (try { open --raw ($gitdir | path join HEAD) | str trim } catch { return "" })
    if ($head | str starts-with "ref: ") {
        $head | str replace "ref: " "" | str replace "refs/heads/" ""
    } else {
        $head | str substring 0..<7
    }
}

# What a prompt collapses to once its line is submitted: when it ran, where,
# and on which checkout, dim, so scrollback is commands and output with a
# stamp on each instead of a full module row per command.
#
# A prompt collapses before its command runs, so the only duration it can know
# is the previous command's. `lead` puts that one where `left` already drew it.
# For the same reason the directory and the checkout are the ones the command
# started in: a `git switch` line shows the branch it left.
export def transient []: nothing -> string {
    let dir = ($env.PWD | str replace $nu.home-dir "~")
    let stamp = ([(date now | format date "%a %d %b %Y %H:%M:%S") $dir (head-name)] | where $it != "" | str join "  ")
    $"(lead)(paint dark_gray $stamp)\n"
}
