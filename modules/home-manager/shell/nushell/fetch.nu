# `fetch`: the system summary fastfetch used to print, built from nushell's
# own `sys` commands so no package is needed. Same rows as the old
# programs.fastfetch config, and still no package count: counting the store
# was most of what made fastfetch slow.

def fetch-row [key: string, color: string, value: any]: nothing -> string {
  $"(ansi $color)($key | fill --width 8)(ansi reset)($value)"
}

# The nearest ancestor of this shell that is not itself a shell, multiplexer
# or privilege wrapper, which is how fastfetch finds the terminal too.
def fetch-terminal []: nothing -> string {
  let skip = [nu bash sh zsh fish zellij tmux sudo doas ssh sshd]
  let procs = (ps | select pid ppid name)
  mut pid = $nu.pid
  for _ in 1..10 {
    let me = ($procs | where pid == $pid | get 0?)
    if $me == null { break }
    let parent = ($procs | where pid == $me.ppid | get 0?)
    if $parent == null { break }
    if $parent.name not-in $skip { return $parent.name }
    $pid = $parent.pid
  }
  "unknown"
}

# Print a short system summary: os, kernel, uptime, shell, terminal, wm,
# cpu, memory and the root disk.
def fetch [] {
  let host = (sys host)
  let cpus = (sys cpu)
  let mem = (sys mem)
  let disk = (sys disks | where mount == "/" | get 0?)

  let title = $"($env.USER)@($host.hostname)"
  # Same "used" as fastfetch: what is not available, so cache is not counted.
  let mem_used = ($mem.total - $mem.available)
  let mem_pct = ($mem_used / $mem.total * 100 | math round)
  let up = (($host.uptime / 1min | math floor) * 1min)
  let wm = ($env.XDG_CURRENT_DESKTOP? | default "unknown" | split row ":" | first)

  let rows = [
    (fetch-row os blue $"($host.name) ($host.os_version)")
    (fetch-row kernel blue $host.kernel_version)
    (fetch-row up blue $up)
    (fetch-row shell magenta $"nu ((version).version)")
    (fetch-row term magenta (fetch-terminal))
    (fetch-row wm magenta $wm)
    (fetch-row cpu green $"($cpus.0.brand) \(($cpus | length)\)")
    (fetch-row mem green $"($mem_used) / ($mem.total) \(($mem_pct)%\)")
  ] ++ (if $disk == null { [] } else {
    let used = ($disk.total - $disk.free)
    let pct = ($used / $disk.total * 100 | math round)
    [(fetch-row disk green $"($used) / ($disk.total) \(($pct)%\)")]
  })

  # The eight normal ANSI colors, like fastfetch's colors module.
  let colors = (0..7 | each {|i| $"(ansi --escape $"3($i)m")●" } | str join " ")

  print $"(ansi attr_bold)($title)(ansi reset)"
  print ("" | fill --character "-" --width ($title | str length))
  $rows | each {|r| print $r } | ignore
  print ""
  print $"($colors)(ansi reset)"
}
