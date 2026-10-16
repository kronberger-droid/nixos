#!@nu@/bin/nu --no-std-lib

# flake-versions: what an update of this flake would and would not change,
# beyond what `nix store diff-closures` already says.
#
#   pins      packages the flake overrides, against plain nixpkgs: whether
#             nixpkgs caught up, and whether its build is in the cache, so a
#             pin can be dropped without compiling anything
#   uncached  packages a host would compile instead of fetch
#   inputs    each flake input's locked rev against its branch upstream
#   upstream  (--upstream) the newest release Repology knows, per package
#
# `report --json` is what the flake-autoupdate job writes into its run
# directory for the PR agent; `tui` shows the same report interactively.

const COLLECT = "@collect@"

# A flake reference nix accepts for a local checkout. git+file keeps nix to
# tracked files, the same view `nix build .#…` has.
def flake-url [dir: path]: nothing -> string {
  let abs = ($dir | path expand)
  if ($abs | path join .git | path exists) { $"git+file://($abs)" } else { $"path:($abs)" }
}

# The derivations a `nix build --dry-run` would build, from its stderr.
def will-build [...installables: string]: nothing -> list<string> {
  if ($installables | is-empty) { return [] }
  let lines = (^nix build --dry-run --no-link ...$installables | complete | get stderr | lines)
  mut out = []
  mut inside = false
  for l in $lines {
    if ($l =~ 'will be built:$') { $inside = true; continue }
    if $inside and ($l | str starts-with '  /nix/store/') {
      $out = ($out | append ($l | str trim))
    } else {
      $inside = false
    }
  }
  $out
}

# `foo-1.2.3` into pname and version; null when there is no version part.
def split-name [name: string]: nothing -> any {
  $name | parse --regex '^(?<pname>.+?)-(?<version>[0-9].*)$' | get 0?
}

def collect-packages [url: string, hosts: any]: nothing -> record {
  let hosts_nix = if $hosts == null { "null" } else {
    $"builtins.fromJSON ''($hosts | to json --raw)''"
  }
  let expr = $"import ($COLLECT) { flake = builtins.getFlake \"($url)\"; hosts = ($hosts_nix); }"
  let r = (^nix eval --impure --json --expr $expr | complete)
  if $r.exit_code != 0 {
    error make {msg: $"collecting packages failed:\n($r.stderr | lines | last 15 | str join "\n")"}
  }
  $r.stdout | from json
}

# Homepages differ in spelling more than in substance: `https://www.x.sh`
# and `https://x.sh/` are the same project.
def normalize-url [url: string]: nothing -> string {
  $url | str lowercase | str replace --regex '^[a-z]+://(www\.)?' '' | str trim --right --char '/'
}

# Overridden packages, one row per package across hosts.
def pins [collected: record]: nothing -> table {
  let rows = ($collected | transpose host pkgs | each {|h|
    $h.pkgs | where overridden | each {|p| $p | insert host $h.host }
  } | flatten)
  if ($rows | is-empty) { return [] }

  # Only the packages where nixpkgs is ahead need the cache asked: those are
  # the pins that might go.
  let ahead = ($rows | where cmp == 1 and nixpkgsDrvPath != null | get nixpkgsDrvPath | uniq)
  # (A few of these are filtered out below as not comparable; asking the
  # cache about them anyway costs one dry run, not one per package.)
  let uncached = (will-build ...($ahead | each {|d| $"($d)^*" }))

  $rows
  | group-by pname
  | transpose pname rows
  | each {|g|
    let p = ($g.rows | first)
    # compareVersions has an answer for any two strings, not always a
    # meaningful one: a branch build or a missing version says nothing.
    let comparable = (
      ($p.version | default "") != "" and ($p.nixpkgsVersion | default "") != ""
      and not ($p.version =~ 'unstable') and not ($p.nixpkgsVersion =~ 'unstable')
    )
    let same_project = (
      $p.homepage == null or $p.nixpkgsHomepage == null
      or (normalize-url $p.homepage) == (normalize-url $p.nixpkgsHomepage)
    )
    let cmp = if $comparable and $same_project { $p.cmp } else { null }
    let status = if not $same_project { "other project: only the name matches" } else { match $cmp {
      1 => {
        if $p.nixpkgsDrvPath in $uncached {
          "keep: nixpkgs is newer but not in the cache"
        } else {
          "droppable: nixpkgs is newer and cached"
        }
      }
      0 => "patched: same version, rebuilt by an overlay"
      -1 => "ahead: newer than nixpkgs"
      _ => "custom: versions not comparable"
    } }
    {
      package: $g.pname
      flake: $p.version
      nixpkgs: $p.nixpkgsVersion
      status: $status
      hosts: ($g.rows | get host | uniq)
    }
  }
  | sort-by status package
}

# Packages each host would compile. Taken from the toplevel's dry run, so a
# dependency like the nix daemon counts too, not just the installed list.
# Derivations without a version (units, config files, wrappers) are noise
# that every rebuild has, and are left out.
def uncached [url: string, hosts: list<string>]: nothing -> table {
  let noise = '^(nixos-system|home-manager|hm_|unit-|X-Re|system-|user-|etc|activat|nixos-tmpfiles)'
  $hosts
  | each {|h|
    will-build $"($url)#nixosConfigurations.($h).config.system.build.toplevel"
    | each {|drv|
      let name = ($drv | path basename | str replace --regex '^[a-z0-9]{32}-' '' | str replace --regex '\.drv$' '')
      let parts = (split-name $name)
      if $parts == null or ($parts.pname =~ $noise) { null } else {
        {package: $parts.pname, version: $parts.version, host: $h, drv: $drv}
      }
    }
    | compact
  }
  | flatten
  | group-by package
  | transpose package rows
  | each {|g| {package: $g.package, version: ($g.rows.0.version), hosts: ($g.rows | get host | uniq), drv: $g.rows.0.drv} }
  | sort-by package
}

# Each GitHub or git input's locked rev against the tip of its branch.
def inputs [dir: path]: nothing -> table {
  let lock = (open --raw ($dir | path join flake.lock) | from json)
  let root = ($lock.nodes | get $lock.root | get inputs)
  let has_gh = (which gh | is-not-empty)
  $root
  | transpose input node
  # A follows entry is a path list, not a node of its own.
  | where ($it.node | describe) == string
  | each {|i|
    let n = ($lock.nodes | get $i.node)
    let locked = ($n.locked? | default {})
    let original = ($n.original? | default {})
    let url = match ($locked.type? | default "") {
      "github" => $"https://github.com/($locked.owner)/($locked.repo)"
      "git" => $locked.url
      _ => null
    }
    if $url == null or $locked.rev? == null { return null }
    # Whole days, so the number survives the JSON round trip the job does.
    let days = (((date now) - ($locked.lastModified * 1_000_000_000 | into datetime)) / 1day | math floor)
    if $original.rev? != null {
      return {input: $i.input, locked: ($locked.rev | str substring 0..<7), remote: null, behind: null, days: $days, status: "pinned to a rev", url: $url}
    }
    let ref = ($original.ref? | default "HEAD")
    let remote = (^git ls-remote $url $ref | complete | get stdout | lines | get 0? | default "" | split row "\t" | get 0)
    let behind = if $has_gh and $remote != "" and $remote != $locked.rev and $locked.type == "github" {
      ^gh api $"repos/($locked.owner)/($locked.repo)/compare/($locked.rev)...($remote)" --jq .ahead_by
      | complete | if $in.exit_code == 0 { $in.stdout | str trim | into int } else { null }
    } else if $remote == $locked.rev { 0 } else { null }
    let status = if $remote == "" { "remote unreachable" } else if $remote == $locked.rev { "current" } else { "behind" }
    {
      input: $i.input
      locked: ($locked.rev | str substring 0..<7)
      remote: (if $remote == "" { null } else { $remote | str substring 0..<7 })
      behind: $behind
      days: $days
      status: $status
      url: $url
    }
  }
  | compact
  | sort-by status input
}

# The newest release Repology knows, one request a second as its API asks.
# Returns a lazy stream, so the TUI fills in as answers arrive.
def upstream [collected: record] {
  $collected
  | values
  | flatten
  | where attr != null
  | uniq-by pname
  | sort-by pname
  | each {|p|
    sleep 1sec
    let projects = (try {
      http get --headers {User-Agent: "flake-versions (nixos config tooling)"} $"https://repology.org/api/v1/project/($p.pname)"
    } catch { [] })
    let newest = ($projects | where status? == newest | get version? | get 0?)
    let ours = ($projects | where repo? == nix_unstable | get 0?)
    {
      package: $p.pname
      flake: $p.version
      upstream: $newest
      repology: ($ours.status? | default "unknown")
    }
  }
}

# `--hosts a,b` as a list; an empty string is no hosts (a flake without
# nixosConfigurations), a missing flag is this machine.
def host-list [hosts: any, all: bool]: nothing -> any {
  if $all { return null }
  if $hosts == null { return [(sys host | get hostname)] }
  $hosts | split row "," | str trim | compact --empty
}

# Collect the report for a flake checkout.
def "main report" [
  --flake (-f): path = "."     # the flake checkout to inspect
  --hosts: string              # comma-separated hosts; default: this machine's hostname
  --all-hosts                  # every nixosConfiguration of this system
  --upstream                   # also ask Repology, about one second per package
  --json                       # print JSON instead of a table, for the update job
] {
  let url = (flake-url $flake)
  let hosts = (host-list $hosts $all_hosts)
  let collected = (collect-packages $url $hosts)
  let report = {
    generated: (date now | format date "%Y-%m-%dT%H:%M:%S%z")
    hosts: ($collected | columns)
    pins: (pins $collected)
    uncached: (uncached $url ($collected | columns))
    inputs: (inputs $flake)
    upstream: (if $upstream { upstream $collected | collect } else { null })
  }
  if $json { $report | to json } else { $report }
}

# Browse the report: one tab per section, `/` to search.
def "main tui" [
  --flake (-f): path = "."
  --hosts: string              # comma-separated hosts; default: this machine's hostname
  --all-hosts
  --upstream                   # add an upstream tab, filled in as Repology answers
  --from: path                 # read a report written by `report --json` instead
] {
  let report = if $from != null { open $from } else {
    let url = (flake-url $flake)
    let hosts = (host-list $hosts $all_hosts)
    let collected = (collect-packages $url $hosts)
    {
      hosts: ($collected | columns)
      pins: (pins $collected)
      uncached: (uncached $url ($collected | columns))
      inputs: (inputs $flake)
      collected: $collected
    }
  }

  # One tab: a search box over a table of the short columns, and the whole
  # highlighted row beside it. Lists (hosts) are joined so the table shows
  # them instead of "[list 1 item]".
  let section = {|id, rows, columns|
    let flat = ($rows | each {|row|
      $row | items {|k, v| {k: $k, v: (if ($v | describe) =~ '^list' { $v | str join ", " } else { $v })} }
      | reduce --fold {} {|kv, acc| $acc | insert $kv.k $kv.v }
    })
    [
      (tui search --bind / --placeholder "/ to search")
      (tui split --sizes [65% 1fr] [
        (tui table --id $id --data $flat --columns $columns)
        (tui preview --from $id {|row|
          $row | items {|k, v| $"($k): ($v)" } | str join "\n"
        })
      ])
    ]
  }

  mut ui = (tui label --titlebar $"flake-versions: ($report.hosts | str join ', ')")
  $ui = ($ui | tui tab $"pins \(($report.pins | length)\)" (do $section pins $report.pins [package flake nixpkgs status hosts]))
  $ui = ($ui | tui tab $"uncached \(($report.uncached | length)\)" (do $section uncached $report.uncached [package version hosts]))
  $ui = ($ui | tui tab $"inputs \(($report.inputs | length)\)" (do $section inputs $report.inputs [input status behind days locked remote]))
  let upstream_cols = [package flake upstream repology]
  if $upstream and ($report.collected? != null) {
    $ui = ($ui | tui tab "upstream" (do $section upstream (upstream $report.collected) $upstream_cols))
  } else if ($report.upstream? | default null) != null {
    $ui = ($ui | tui tab "upstream" (do $section upstream $report.upstream $upstream_cols))
  }
  $ui
  | tui label --status "/ search"
  | tui run
  | ignore
}

def main [] {
  help main
}
