# `cl`: Claude Code in the sandbox's checkout of this repo if it has one,
# otherwise right here. The sandbox account and its layout are in
# system/security/agent-sandbox.nix.
#
# The sandbox mirrors ~/Projects: ~/Projects/rust/reedline here is
# /home/claude/Projects/rust/reedline there, so a path means the same thing on
# both sides. That mirror path is tried first. Inside ~/Projects with no
# mirror yet, `cl` offers to clone it (the fork, `gh repo clone` adds the
# parent as `upstream`). Anywhere else it runs here.
#
# Failing the path, "same repo" means the two checkouts share a GitHub remote, compared as
# owner/repo. Directory names miss the common case: here `origin` is
# nushell/reedline, while the sandbox clones kronberger-droid/reedline and
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

const CL_MIRROR = "/home/claude/Projects"

# Where the repo containing the current directory lives in the mirror, or null
# outside ~/Projects. The checkout there may not exist yet.
def cl-mirror-path []: nothing -> any {
    let here = (^git rev-parse --show-toplevel | complete)
    if $here.exit_code != 0 { return null }
    let top = ($here.stdout | str trim)
    let projects = ($nu.home-dir | path join "Projects")
    if not ($top | str starts-with $"($projects)/") { return null }
    $CL_MIRROR | path join ($top | path relative-to $projects)
}

def cl-sandboxed []: nothing -> bool {
    (which claude-sandbox | is-not-empty) and ((whoami) != "claude")
}

# owner/repo for every network remote of the checkout at `dir`. Local-path
# remotes are dropped: they name a directory, not a repo.
#
# --untrusted for the sandbox's checkouts: `git config --file` reads that one
# file and discovers no repository, so nothing in it is acted on. A linked
# worktree there (.git as a file) has no such config and is skipped. The
# primary user's own checkout goes through git as usual, worktrees included.
def cl-remotes [dir: path, --untrusted]: nothing -> list<string> {
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

# Sandbox checkouts of the repo the current directory is in. Empty outside a
# repo, on a host without the sandbox, and from inside the sandbox itself.
# development.nu's `dev` asks this too, to decide where its Claude pane goes.
def cl-matches []: nothing -> list<string> {
    let here = (^git rev-parse --show-toplevel | complete)
    let mine = if $here.exit_code == 0 { cl-remotes ($here.stdout | str trim) } else { [] }
    if ($mine | is-empty) or (not (cl-sandboxed)) { return [] }

    # Group membership is read at login, so a session older than the rebuild
    # that added it cannot list the sandbox yet.
    if not (try { ls /home/claude | ignore; true } catch { false }) {
        print $"(ansi yellow)cl:(ansi reset) cannot read /home/claude, log in again to pick up the `claude` group. Starting here."
        return []
    }

    # The mirror path first, then any other checkout (reedline-pr1183 and the
    # like) that shares a remote. Mirror checkouts sit two levels down,
    # <language>/<repo>.
    let mirror = cl-mirror-path
    let exact = if $mirror != null and ($mirror | path join ".git" | path exists) { [$mirror] } else { [] }
    let siblings = (
        glob --no-file $"($CL_MIRROR)/*/*"
        | where {|dir| cl-remotes --untrusted $dir | any {|r| $r in $mine } }
    )
    $exact | append $siblings | uniq
}

# Clone the current repo into its mirror path, as the sandbox account, after
# asking. Returns the new path, or null if declined or it failed.
def cl-create [dest: path]: nothing -> any {
    let top = (^git rev-parse --show-toplevel | str trim)
    let remotes = (cl-remotes $top)
    if ($remotes | is-empty) {
        print $"(ansi yellow)cl:(ansi reset) no GitHub remote to clone from. Starting here."
        return null
    }
    let repo = $"kronberger-droid/($remotes | first | split row '/' | last)"
    let answer = (try { input $"No sandbox checkout at ($dest). Clone ($repo) there? [y/N] " } catch { "n" })
    if ($answer | str downcase) not-in ["y" "yes"] { return null }

    ^claude-sandbox /run/current-system/sw/bin/nu -l -c $"mkdir ($dest | path dirname | to nuon); gh repo clone ($repo) ($dest | to nuon)"
    if ($dest | path join ".git" | path exists) { return $dest }
    print $"(ansi yellow)cl:(ansi reset) clone did not produce ($dest). Starting here."
    null
}

# Open Claude Code in the sandbox's checkout of this repo, else here.
# Extra arguments go to `claude` unchanged, e.g. `cl --resume`.
def --wrapped cl [...args: string] {
    let mirror = cl-mirror-path
    let matches = cl-matches
    let target = match ($matches | length) {
        0 => (if $mirror != null and (cl-sandboxed) { cl-create $mirror } else { null })
        1 => ($matches | first)
        _ if $mirror != null and ($mirror in $matches) => $mirror
        _ => {
            let here_label = "here (outside the sandbox)"
            let pick = (try { $matches | append $here_label | input list "Several sandbox checkouts match:" } catch { null })
            if $pick == null { return }
            if $pick == $here_label { null } else { $pick }
        }
    }

    if $target == null {
        ^claude ...$args
        return
    }

    print $"(ansi cyan)sandbox:(ansi reset) ($target)"
    let argv = ($args | each {|a| $a | to nuon } | str join " ")
    ^claude-sandbox /run/current-system/sw/bin/nu -l -c $"cd ($target | to nuon); claude ($argv)"
}
