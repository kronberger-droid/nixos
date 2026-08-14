#!@nu@/bin/nu -n

def active? [unit: string] {
  (^@systemd@/bin/systemctl is-active $unit | complete).exit_code == 0
}

# sudo wrapper and system systemctl by absolute path, as in the bash version.
# Neither is a store path, so neither is substituted.
def stop-unit [unit: string] {
  ^/run/wrappers/bin/sudo /run/current-system/sw/bin/systemctl stop $unit | complete | ignore
}

mut any_active = false

if (^@tailscale@/bin/tailscale status | complete).exit_code == 0 {
  ^@tailscale@/bin/tailscale down | complete | ignore
  $any_active = true
}

# `for` rather than `each`: a closure cannot assign to an outer `mut`.
for unit in ["pia-vpn.service" "openconnect-tuwien.service"] {
  if (active? $unit) {
    stop-unit $unit
    $any_active = true
  }
}

let msg = if $any_active { "All VPNs disconnected" } else { "No VPNs were active" }
^@libnotify@/bin/notify-send "VPN" $msg -i network-vpn-disconnected | complete | ignore

^@procps@/bin/pkill -RTMIN+8 waybar | complete | ignore
