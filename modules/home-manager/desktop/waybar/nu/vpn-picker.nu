#!@nu@/bin/nu -n

def active? [unit: string] {
  (^@systemd@/bin/systemctl is-active $unit | complete).exit_code == 0
}

def notify [body: string, icon: string] {
  ^@libnotify@/bin/notify-send "VPN" $body -i $icon | complete | ignore
}

def systemctl-user [verb: string, unit: string] {
  ^/run/wrappers/bin/sudo /run/current-system/sw/bin/systemctl $verb $unit | complete | ignore
}

# PIA and TU Wien differ only in unit and label. Tailscale has no systemd unit
# and no connect delay, so it stays separate.
def toggle-unit [unit: string, label: string, on: bool] {
  if $on {
    systemctl-user "stop" $unit
    notify $"($label) disconnected" "network-vpn-disconnected"
  } else {
    notify $"Connecting to ($label)..." "network-vpn"
    systemctl-user "start" $unit
    sleep 3sec
    if (active? $unit) {
      notify $"($label) connected" "network-vpn"
    } else {
      notify $"Failed to connect to ($label)" "dialog-error"
    }
  }
}

let tailscale_on = ((^@tailscale@/bin/tailscale status | complete).exit_code == 0)
let pia_on = (active? "pia-vpn.service")
let tuwien_on = (active? "openconnect-tuwien.service")

let entries = [
  {name: "Tailscale", on: $tailscale_on}
  {name: "PIA VPN", on: $pia_on}
  {name: "TU Wien VPN", on: $tuwien_on}
]

let selected = ($entries
  | each {|e| if $e.on { $"[ON]  ($e.name)" } else { $"[OFF] ($e.name)" }}
  | str join "\n"
  | ^@rofi@/bin/rofi -dmenu -i -p "VPN" -theme-str 'window {width: 400px;} listview {lines: 3;}'
  | complete
  | get stdout
  | str trim)

# Strip the status prefix back off.
let name = ($selected | str replace --regex '^\[O[NF]*\] *' '')

if ($name | is-empty) { exit 0 }

match $name {
  "Tailscale" => {
    if $tailscale_on {
      ^@tailscale@/bin/tailscale down | complete | ignore
      notify "Tailscale disconnected" "network-vpn-disconnected"
    } else {
      ^@tailscale@/bin/tailscale up | complete | ignore
      notify "Tailscale connected" "network-vpn"
    }
  }
  "PIA VPN" => { toggle-unit "pia-vpn.service" "PIA VPN" $pia_on }
  "TU Wien VPN" => { toggle-unit "openconnect-tuwien.service" "TU Wien VPN" $tuwien_on }
  _ => {}
}

^@procps@/bin/pkill -RTMIN+8 waybar | complete | ignore
