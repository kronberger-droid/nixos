#!@nu@/bin/nu -n

# `claude` for the primary user: Claude Code in the sandbox account, always.
# Installed under that name by agent-sandbox.nix, which also keeps the real
# binary out of the primary user's profile, so a keybind, `sh -c claude` or a
# restored terminal lands here the same as typing it does. Nothing in this
# file starts Claude Code on this side of the boundary.
#
# Where the session opens, in order:
#   1. the sandbox's checkout of the repo the current directory is in
#   2. a fresh clone of it, after asking
#   3. the current directory itself, where the sandbox can read it (~/Projects,
#      read-only there)
#   4. the sandbox's home
#
# The sandbox mirrors ~/Projects: ~/Projects/rust/reedline here is
# /home/claude/Projects/rust/reedline there, so a path means the same thing on
# both sides. That mirror path is tried first. A new clone (the fork, `gh repo
# clone` adds the parent as `upstream`) goes to the mirror path inside
# ~/Projects, to other/<repo> for a repo elsewhere.
#
# Failing the path, "same repo" means the two checkouts share a GitHub remote,
# compared as owner/repo. Directory names miss the common case: here `origin`
# is nushell/reedline, while the sandbox clones kronberger-droid/reedline and
# carries nushell/reedline as `upstream`, possibly under a name like
# reedline-pr1183.
#
# The scan runs as the primary user, who reads /home/claude through the
# `claude` group. It reads each checkout's .git/config as a plain file
# rather than running git inside the tree: these repositories are not
# trusted (no safe.directory, see git.nix), and their config is the agent's
# to write. Only the launch crosses over. `nu -l` there, since machinectl
# starts from an empty environment and only a login shell sources
# extra_env.nu, which is where the sandbox's GH_TOKEN comes from.
#
# The shebang names nu directly, without the `env -S` the bar's scripts use:
# the kernel then names the process after this file, and the workspace saver
# (ironbar/nu/workspaces.nu) recognises a terminal running `claude` by that.

const SANDBOX = "@claudeSandbox@"
const MIRROR = "/home/claude/Projects"
# The remote this user's repos know their sandbox checkout by; `git
# fetch-sandbox` (git.nix) defaults to the same name.
const REMOTE = "sandbox"
# As the sandbox account sees it.
const SANDBOX_NU = "/run/current-system/sw/bin/nu"
# Environment a wrapper such as `claude-math` sets for Claude Code and that
# machinectl's clean environment would drop.
const FORWARD_ENV = ["CLAUDE_CODE_FORCE_TERMINAL_IMAGES"]

def note [msg: string] {
    print -e $"(ansi yellow)claude:(ansi reset) ($msg)"
}

# Top of the repo containing the current directory, or null outside one.
def repo-top []: nothing -> any {
    let here = (^git rev-parse --show-toplevel | complete)
    if $here.exit_code == 0 { $here.stdout | str trim } else { null }
}

# Where the repo at `top` lives in the mirror, or null outside ~/Projects.
# The checkout there may not exist yet.
def mirror-path [top: string]: nothing -> any {
    let projects = ($nu.home-dir | path join "Projects")
    if not ($top | str starts-with $"($projects)/") { return null }
    $MIRROR | path join ($top | path relative-to $projects)
}

# Where a new sandbox checkout of the repo at `top` goes: the mirror path, or
# other/<repo> for a repo outside ~/Projects. Two levels down either way,
# since that is the depth `checkouts` scans.
def clone-dest [top: string]: nothing -> string {
    mirror-path $top | default ($MIRROR | path join "other" ($top | path basename))
}

# owner/repo for every network remote of the checkout at `dir`. Local-path
# remotes are dropped: they name a directory, not a repo.
#
# --untrusted for the sandbox's checkouts: `git config --file` reads that one
# file and discovers no repository, so nothing in it is acted on. A linked
# worktree there (.git as a file) has no such config and is skipped. The
# primary user's own checkout goes through git as usual, worktrees included.
def remotes [dir: path, --untrusted]: nothing -> list<string> {
    let out = if $untrusted {
        let config = ($dir | path join ".git" "config")
        if not ($config | path exists) { return [] }
        ^git config --file $config --get-regexp '^remote\..*\.url$' | complete
    } else {
        ^git -C $dir config --get-regexp '^remote\..*\.url$' | complete
    }
    if $out.exit_code != 0 { return [] }
    $out.stdout
    | lines
    | each {|line| $line | split row -r '\s+' | get 1 }
    | where {|url| $url =~ '^(https?://|ssh://|git@)' }
    | each {|url|
        $url
        | str replace -r '(\.git)?/?$' ''
        | split row -r '[:/]'
        | last 2
        | str join '/'
        | str lowercase
    }
    | uniq
}

# Sandbox checkouts of the repo at `top`: the mirror path first, then any
# other checkout (reedline-pr1183 and the like) that shares a remote. Mirror
# checkouts sit two levels down, <language>/<repo>.
def checkouts [top: string, mine: list<string>]: nothing -> list<string> {
    let mirror = (mirror-path $top)
    let exact = if $mirror != null and ($mirror | path join ".git" | path exists) { [$mirror] } else { [] }
    let siblings = if ($mine | is-empty) { [] } else {
        glob --no-file $"($MIRROR)/*/*"
        | where {|dir| remotes --untrusted $dir | any {|r| $r in $mine } }
    }
    $exact | append $siblings | uniq
}

# Clone the repo into `dest`, as the sandbox account, after asking. Returns
# the new path, or null if declined or it failed.
#
# The question is printed and only the last few words are `input`'s prompt:
# `input` repaints its prompt on every keystroke and clears one terminal row
# to do it, so a prompt long enough to wrap in a narrow pane leaves a copy of
# itself behind per key.
def clone [dest: path, source: record]: nothing -> any {
    print -e "No sandbox checkout of this repo yet."
    print -e $"  clone ($source.label)"
    print -e $"  into  ($dest)"
    let answer = (try { input "Clone? [y/N] " } catch { "n" })
    if ($answer | str trim | str lowercase) not-in ["y" "yes"] { return null }

    try {
        ^$SANDBOX $SANDBOX_NU -l -c $"mkdir ($dest | path dirname | to nuon); ($source.command) ($dest | to nuon)"
    }
    if ($dest | path join ".git" | path exists) { return $dest }
    note $"clone did not produce ($dest)."
    if $source.hint != null { note $source.hint }
    null
}

# What a sandbox checkout of the repo at `top` is cloned from, or null when
# it has no network remote. `origin` decides, else the first remote.
#
# On GitHub that is the fork under kronberger-droid, through `gh`, which
# authenticates with the sandbox's token and adds the parent as `upstream`.
# Anywhere else it is the remote's own URL, as it stands: the sandbox account
# reaches that host with its own ssh key or not at all.
def clone-source [top: string]: nothing -> any {
    let names = (^git -C $top remote | complete | get stdout | lines | where $it != $REMOTE)
    if ($names | is-empty) { return null }
    let name = if "origin" in $names { "origin" } else { $names | first }
    let url = (^git -C $top remote get-url $name | complete | get stdout | str trim)
    if $url !~ '^(https?://|ssh://|git@)' { return null }

    if $url =~ '^(https?://|ssh://git@|git@)github\.com[:/]' {
        let repo = $"kronberger-droid/($url | str replace -r '(\.git)?/?$' '' | split row -r '[:/]' | last)"
        { label: $repo, command: $"gh repo clone ($repo)", hint: null }
    } else {
        {
            label: $url
            command: $"git clone -- ($url | to nuon)"
            hint: "the sandbox account needs access of its own to that host: its key is /home/claude/.ssh/id_ed25519.pub"
        }
    }
}

# Point the `sandbox` remote of the repo at `top` at its sandbox checkout, so
# work comes back with `git fetch-sandbox` and `git merge sandbox/<branch>`
# (git.nix). Checked on every launch rather than once at clone time: that
# also covers checkouts older than this, and remotes left pointing at a
# place the sandbox has moved away from.
#
# Only for the checkout at the repo's own place in the mirror. A side
# checkout (reedline-pr1183) is fetched by path and does not take the name.
# The URL is inert as config: a plain `git fetch sandbox` still stops at
# git's ownership check, and `fetch-sandbox` is what lifts it, per command.
def link-remote [top: string, checkout: string, quiet: bool] {
    if $checkout != (clone-dest $top) { return }
    if not ($checkout | path join ".git" | path exists) { return }
    let current = (^git -C $top remote get-url $REMOTE | complete)
    let done = if $current.exit_code != 0 {
        ^git -C $top remote add $REMOTE $checkout | complete
    } else if ($current.stdout | str trim) != $checkout {
        ^git -C $top remote set-url $REMOTE $checkout | complete
    } else {
        return
    }
    if $done.exit_code != 0 {
        note $"could not set the `($REMOTE)` remote: ($done.stderr | str trim)"
    } else if not $quiet {
        note $"remote `($REMOTE)` -> ($checkout)"
    }
}

# The sandbox checkout to open for the repo at `top`, or null for none.
# `ask` is false when nobody is there to answer a question.
def pick [top: string, ask: bool]: nothing -> any {
    # Group membership is read at login, so a session older than the rebuild
    # that added it cannot list the sandbox yet. The mirror path is still the
    # best guess, and the sandbox side falls back if it is not there.
    if not (try { ls /home/claude | ignore; true } catch { false }) {
        note "cannot read /home/claude, log in again to pick up the `claude` group."
        return (mirror-path $top)
    }

    let mine = (remotes $top)
    let mirror = (mirror-path $top)
    let found = (checkouts $top $mine)
    match ($found | length) {
        0 => {
            let source = if $ask { clone-source $top } else { null }
            if $source == null { null } else { clone (clone-dest $top) $source }
        }
        1 => ($found | first)
        _ if $mirror != null and ($mirror in $found) => $mirror
        _ if not $ask => ($found | first)
        _ => {
            let choice = (try { $found | input list "Several sandbox checkouts match:" } catch { null })
            if $choice == null { exit 1 }
            $choice
        }
    }
}

# Open Claude Code in the sandbox. Arguments go to `claude` there unchanged,
# e.g. `claude --resume`.
def --wrapped main [...args: string] {
    # `-p` answers on stdout and a pipe has nobody at the keyboard: no
    # questions, and no banner in the output.
    let headless = (not (is-terminal --stdin)) or ($args | any {|a| $a in ["-p" "--print"] })

    let top = (repo-top)
    let checkout = if $top == null { null } else { pick $top (not $headless) }
    if $checkout != null { link-remote $top $checkout $headless }
    let dir = ($checkout | default $env.PWD)

    # Run by the sandbox's login shell. The directory is settled there, since
    # only that side knows what it can enter: a checkout of its own, a tree
    # of the primary user's it may read, or neither.
    let banner = 'print -e $"(ansi cyan)sandbox:(ansi reset) (pwd)(if ((pwd) starts-with $nu.home-dir) { "" } else { " (read-only)" })"'
    let forwarded = (
        $FORWARD_ENV
        | where {|name| $name in $env }
        | each {|name| $"$env.($name) = ($env | get $name | to nuon)" }
    )
    let argv = ($args | each {|a| $a | to nuon } | str join " ")
    let script = (
        [$"try { cd ($dir | to nuon) } catch { cd ~ }"]
        | append (if $headless { [] } else { [$banner] })
        | append $forwarded
        | append $"claude ($argv)"
        | str join "; "
    )

    try {
        ^$SANDBOX $SANDBOX_NU -l -c $script
    } catch {
        exit ($env.LAST_EXIT_CODE? | default 1)
    }
}
