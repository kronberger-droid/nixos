# OnlyOffice is the Flathub build, see flatpak.nix. With its own title bar
# (titlebar=custom) it draws a frame with a wide shadow margin inside the
# window, which shows as a thick dead border in a tiled niri column. The
# system title bar leaves the frame to the compositor.
#
# The app keeps theme and window state in the same file and rewrites it on
# exit, so only this key is set, and a switch while it runs is undone when
# it quits.
{lib, ...}: {
  home.activation.onlyofficeTitlebar = lib.hm.dag.entryAfter ["writeBoundary"] ''
    conf="$HOME/.var/app/org.onlyoffice.desktopeditors/config/onlyoffice/DesktopEditors.conf"
    if [ ! -f "$conf" ]; then
      $DRY_RUN_CMD mkdir -p "$(dirname "$conf")"
      $DRY_RUN_CMD sh -c 'printf "[General]\ntitlebar=system\n" > "$1"' _ "$conf"
    elif grep -q '^titlebar=' "$conf"; then
      $DRY_RUN_CMD sed -i 's/^titlebar=.*/titlebar=system/' "$conf"
    else
      $DRY_RUN_CMD sed -i '/^\[General\]/a titlebar=system' "$conf"
    fi
  '';
}
