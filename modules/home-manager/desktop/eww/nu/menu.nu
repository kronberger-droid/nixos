#!@nu@/bin/nu -n

# The bar's two rofi buttons.
#
# These went through an eww launcher and power menu for a while and came back.
# rofi's drun launches applications with the environment they expect, which the
# eww launcher did not: it spawned Exec= through setsid and steam would not
# start. rofi also handles arrow-key navigation, which eww cannot do at all,
# since it exposes no key events.
#
# A script rather than a bare command in the yuck, because widget files are
# copied verbatim and never see replaceVars, so a store path cannot be
# interpolated into one.

def "main launcher" [] {
  ^@rofi@/bin/rofi -show drun | complete | ignore
}

def "main power" [] {
  # Installed by rofi.nix at a runtime path, not a store path.
  let cfg = ($env.XDG_CONFIG_HOME? | default $"($env.HOME)/.config")
  ^($cfg | path join "rofi" "powermenu" "powermenu.sh") | complete | ignore
}
