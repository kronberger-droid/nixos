#!@coreutils@/bin/env -S @nu@/bin/nu -n --no-std-lib

# waybar's `temperature` module: the CPU package sensor, critical at 80°C.
#
# A status script rather than a sys_info token, since sys_info has no state
# class to turn red with. The package sensor is coretemp's "Package id 0",
# which `sensors` prints under that name; a machine without coretemp falls
# back to the first thermal zone.

const CRITICAL = 80

def package-temp []: nothing -> any {
  let labels = (glob /sys/class/hwmon/hwmon*/temp*_label)
  let hit = ($labels | where {|f| (open --raw $f | str trim) == "Package id 0" } | get 0?)
  let input = if $hit != null {
    $hit | str replace "_label" "_input"
  } else {
    "/sys/class/thermal/thermal_zone0/temp"
  }
  if not ($input | path exists) { return null }
  (open --raw $input | str trim | into int) // 1000
}

def main [] {
  let t = (package-temp)
  if $t == null {
    print ({text: "", class: ""} | to json --raw)
    return
  }
  print ({
    text: $"($t)°C \u{f2c9}"
    tooltip: $"CPU package: ($t)°C"
    class: (if $t >= $CRITICAL { "critical" } else { "" })
  } | to json --raw)
}
