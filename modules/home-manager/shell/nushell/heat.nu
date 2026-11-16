# Heat: colour by how recently or how much something changed.
#
# `datetime` colours every date cell by age, `ls`'s `modified` column
# included. `lsh` does the same for names, by git churn rather than mtime.
# color_config can't do that part: its closures only see the cell value, and
# ls names get their LS_COLORS from the table's path_columns handling, which
# wins over a `string` closure. So `lsh` styles the name itself.

# Plain ANSI names only, so the terminal resolves them through the base16
# palette (theming/ansi.nix). base09 is red in this scheme, so bold red stands
# in for the hottest step instead of an orange.

# Age bands for date cells, newest first.
const HEAT_AGE = [
    [max color];
    [1hr red_bold] [6hr red] [1day yellow] [3day green]
    [1wk cyan] [6wk blue] [52wk magenta]
]

# Churn bands for `lsh`, commits touching the path inside the window.
const HEAT_CHURN = [
    [min color];
    [50 red_bold] [20 red] [8 yellow] [3 green] [1 cyan]
]

$env.config.color_config.datetime = {||
    let age = (date now) - $in
    $HEAT_AGE | where max > $age | get -o 0.color | default dark_gray
}

# Commits per path since `since`, for every file and each of its parent
# directories, keyed repo-root relative. A directory counts each commit once,
# however many of its files it touched. Cached per HEAD, window and day, so
# repeat calls cost a file read; uncommitted edits are not counted.
#
# Counts commits rather than lines: --name-only skips the content diffs that
# --numstat needs, 1.1s -> 0.2s for a year of the nushell repo.
def git-heat [since: string]: nothing -> record {
    let key = ([(^git rev-parse HEAD) $since (date now | format date "%F")] | str join | hash md5)
    let cache = ($nu.cache-dir | path join $"heat-($key).nuon")
    if ($cache | path exists) { return (open $cache) }

    let heat = (
        # NUL before each commit's file list, to split on.
        ^git log $"--since=($since)" --name-only --format=%x00 --no-renames
        | split row "\u{0}"
        | each {|commit|
            $commit | lines | compact -e | each {|f|
                let parts = ($f | path split)
                1..($parts | length) | each {|k| $parts | first $k | path join }
            } | flatten | uniq
        }
        | flatten
        | uniq --count
        | each {|r| [$r.value $r.count] }
        | into record
    )
    mkdir $nu.cache-dir
    # A new HEAD or day orphans the old entries, so drop them here.
    glob ($nu.cache-dir | path join "heat-*.nuon")
    | where {|f| ((date now) - (ls $f | get 0.modified)) > 1day }
    | each { rm $in }
    $heat | save -f $cache
    $heat
}

# `ls` with names coloured by git churn and a `heat` column (commits touching
# it since --since). Outside a git repo it is plain `ls`.
def lsh [
    --since: string = "6 weeks ago"  # git log window
    ...paths: glob
]: nothing -> table {
    # `ls ...[]` lists nothing rather than `.`, so supply the default.
    let paths = if ($paths | is-empty) { ["."] } else { $paths }
    let prefix = (^git rev-parse --show-prefix | complete)
    if $prefix.exit_code != 0 { return (ls ...$paths) }
    let prefix = ($prefix.stdout | str trim)
    let heat = (git-heat $since)

    ls ...$paths
    | insert heat {|r| $heat | get -o ($prefix | path join $r.name | path split | path join) | default 0 }
    | update name {|r|
        let c = ($HEAT_CHURN | where min <= $r.heat | get -o 0.color | default dark_gray)
        # Restyling the name drops ls's own OSC 8 link, so add it back.
        let link = ($r.name | path expand | $"file://($in)" | ansi link --text $r.name)
        $"(ansi $c)($link)(ansi reset)"
    }
}
