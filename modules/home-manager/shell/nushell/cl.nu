# `cl`: Claude Code in the sandbox's checkout of this repo if it has one,
# otherwise right here. The sandbox account and its layout are in
# system/security/agent-sandbox.nix.
#
# "Same repo" means the two checkouts share a GitHub remote, compared as
# owner/repo. Directory names miss the common case: here `origin` is
# nushell/reedline, while the sandbox clones kronberger-droid/reedline and
# carries nushell/reedline as `upstream`, possibly under a name like
# reedline-pr1183.
#
# The scan runs as the primary user, who reads /home/claude through the
# `claude` group; git accepts those trees via safe.directory (git.nix). Only
# the launch crosses over. `nu -l` there, since machinectl starts from an
# empty environment and only a login shell sources extra_env.nu, which is
# where the sandbox's GH_TOKEN comes from.

const CL_SANDBOX_SRC = "/home/claude/src"

# owner/repo for every network remote of the checkout at `dir`. Local-path
# remotes are dropped: they name a directory, not a repo.
def cl-remotes [dir: path]: nothing -> list<string> {
    let out = (^git -C $dir remote -v | complete)
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
    let sandboxed = (which claude-sandbox | is-not-empty) and ((whoami) != "claude")
    if ($mine | is-empty) or (not $sandboxed) { return [] }

    # Group membership is read at login, so a session older than the rebuild
    # that added it cannot list the sandbox yet.
    if not (try { ls $CL_SANDBOX_SRC | ignore; true } catch { false }) {
        print $"(ansi yellow)cl:(ansi reset) cannot read ($CL_SANDBOX_SRC), log in again to pick up the `claude` group. Starting here."
        return []
    }

    ls $CL_SANDBOX_SRC
    | where type == dir
    | get name
    | where {|dir| cl-remotes $dir | any {|r| $r in $mine } }
}

# Open Claude Code in the sandbox's checkout of this repo, else here.
# Extra arguments go to `claude` unchanged, e.g. `cl --resume`.
def --wrapped cl [...args: string] {
    let matches = cl-matches
    let target = match ($matches | length) {
        0 => null
        1 => ($matches | first)
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
