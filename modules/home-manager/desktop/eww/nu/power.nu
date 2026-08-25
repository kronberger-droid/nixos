#!@nu@/bin/nu -n
#
# niri and swaymsg are called bare rather than by store path. waybar.nix has to
# gate its niri interpolation on compositor.primary, because pulling the
# source-built niri fork into a sway-only host's closure is expensive; calling
# them bare sidesteps that, and the binary is on PATH inside its own session.
# scratchpad-toggle.nu set this precedent.

# Power menu actions, ported from rofi/powermenu/powermenu.sh.
#
# Split of responsibilities, forced by eww: EWW_CONFIG_DIR is only in scope
# inside widget attributes, not in a defpoll, so the list cannot be generated
# from here and read back. Instead:
#
#   eww.yuck owns presentation  — icons, labels, order, what the filter shows
#   this file owns behaviour    — which actions confirm, and what they run
#
# The seam is the action key. A key in the yuck with no arm here fails loudly
# rather than silently doing nothing.
#
# Two lines of the rofi original did not survive the port: it ran `mpc -q
# pause` and `amixer set Master mute` before suspending, and this system has
# neither mpd nor alsa-utils. Both were inherited from adi1090x's upstream and
# have been no-ops here for as long as they have been in the tree. wpctl is the
# equivalent on pipewire, which is what the volume keys already use.

# Canonical order. `--match` resolves a query against this list, so it has to
# agree with the order eww.yuck renders, or the highlighted row and the row
# Enter actually runs could differ.
const ACTIONS = [
  [key         confirm];
  [lock        false]
  [suspend     true]
  [logout      true]
  [hibernate   true]
  [reboot      true]
  [shutdown    true]
]

# The config dir is our parent: this installs as <eww-config>/scripts/power.
let config_dir = ($env.FILE_PWD | path dirname)

# wpctl's own identifiers happen to look like replaceVars placeholders, and
# replaceVars fails the build on any placeholder it was not given a value for.
# Built by concatenation so the literal pattern never appears here.
const SINK = ("@" + "DEFAULT_AUDIO_SINK" + "@")
const SOURCE = ("@" + "DEFAULT_AUDIO_SOURCE" + "@")

def dismiss [dir: string] {
  # Drop the window before locking or tearing down the session, so it is not
  # still on screen underneath the lock.
  ^@eww@/bin/eww -c $dir update pending=none | complete | ignore
  ^@eww@/bin/eww -c $dir update query="" | complete | ignore
  ^@eww@/bin/eww -c $dir close powermenu | complete | ignore
}

# Same rule the yuck's jq filter uses: case-insensitive substring, first hit in
# canonical order. Returns null on no match, which includes the empty query.
def resolve [query: string]: nothing -> any {
  if ($query | str trim | is-empty) { return null }
  let q = ($query | str lowercase)
  let hit = ($ACTIONS | where {|a| ($a.key | str lowercase) | str contains $q } | get 0?)
  if $hit == null { null } else { $hit.key }
}

def main [
  action?: string   # an action key, when a row is clicked
  --match: string   # a typed query, resolved against ACTIONS
  --confirmed       # skip the prompt; the answer was yes
] {
  let key = if ($match | is-not-empty) { resolve $match } else { $action }

  # Empty or unmatched query: do nothing at all. This is also what makes a
  # stray Enter on an empty search box harmless.
  if ($key | is-empty) { return }

  let entry = ($ACTIONS | where key == $key | get 0?)
  if $entry == null {
    error make {msg: $"unknown action: ($key)"}
  }

  # Park it and let the confirm screen ask, unless the answer is already in.
  if $entry.confirm and (not $confirmed) {
    ^@eww@/bin/eww -c $config_dir update $"pending=($key)" | complete | ignore
    return
  }

  dismiss $config_dir

  match $key {
    "lock" => {
      ^@swaylock@/bin/swaylock -f
    }
    "suspend" => {
      ^@wireplumber@/bin/wpctl set-mute $SINK 1 | complete | ignore
      ^@systemd@/bin/systemctl suspend
    }
    "hibernate" => {
      ^@systemd@/bin/systemctl hibernate
    }
    "reboot" => {
      ^@systemd@/bin/systemctl reboot
    }
    "shutdown" => {
      ^@systemd@/bin/systemctl poweroff
    }
    "logout" => {
      # Same compositor sniff the rofi script used. On the nix side the niri
      # arm needs gating on `compositor.primary`, the way rofi.nix already
      # does: interpolating the niri package drags the source-built fork into
      # the closure on sway-only hosts like mediaBox.
      if ($env.NIRI_SOCKET? | is-not-empty) {
        ^niri msg action quit
      } else if ($env.SWAYSOCK? | is-not-empty) {
        ^swaymsg exit
      }
    }
  }
}
