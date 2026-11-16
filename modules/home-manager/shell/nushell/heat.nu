# Heat: colour by how recently or how much something changed.
#
# `datetime` colours every date cell by age, `ls`'s `modified` column
# included. `lsh` does the same for names, by git churn rather than mtime.
# color_config can't do that part: its closures only see the cell value, and
# ls names get their LS_COLORS from the table's path_columns handling, which
# wins over a `string` closure. So `lsh` styles the name itself.

# Age bands for date cells, newest first.
const HEAT_AGE = [
    [max color];
    [1hr red3b] [6hr orange3] [1day yellow3b] [3day chartreuse2b]
    [1wk green3b] [6wk darkturquoise] [52wk deepskyblue3b]
]

# Churn bands for `lsh`, lines added plus deleted inside the window.
const HEAT_CHURN = [
    [min color];
    [2000 red3b] [500 orange3] [100 yellow3b] [20 chartreuse2b] [1 green3b]
]

$env.config.color_config.datetime = {||
    let age = (date now) - $in
    $HEAT_AGE | where max > $age | get -o 0.color | default dark_gray
}

# Lines changed per path since `since`, for every file and each of its parent
# directories, keyed repo-root relative. Cached per HEAD, window and day, so
# repeat calls cost a file read; uncommitted edits are not counted.
def git-heat [since: string]: nothing -> record {
    let key = ([(^git rev-parse HEAD) $since (date now | format date "%F")] | str join | hash md5)
    let cache = ($nu.cache-dir | path join $"heat-($key).nuon")
    if ($cache | path exists) { return (open $cache) }

    let heat = (
        ^git log $"--since=($since)" --numstat --format= --no-renames
        | lines
        | compact -e
        | parse "{add}\t{del}\t{path}"
        | each {|r|
            # Binary files report "-" for both counts.
            let n = ([$r.add $r.del] | each { if $in == "-" { 0 } else { into int } } | math sum)
            let parts = ($r.path | path split)
            1..($parts | length) | each {|k| {path: ($parts | first $k | path join), n: $n} }
        }
        | flatten
        # group-by, not reduce/upsert: ~5x faster on the nushell repo.
        | group-by path --to-table
        | each {|g| [$g.path ($g.items.n | math sum)] }
        | into record
    )
    mkdir $nu.cache-dir
    $heat | save -f $cache
    $heat
}

# `ls` with names coloured by git churn and a `heat` column (lines changed
# since --since). Outside a git repo it is plain `ls`.
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
