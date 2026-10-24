# Steam is the Flathub build (flatpak.nix). Inside it $HOME is
# ~/.var/app/com.valvesoftware.Steam, so every path below that Steam itself
# reads is rooted there on the host and at the plain home path in the sandbox.
#
# Terraria's August 2026 update moved FNA from SDL2 to SDL3, and SDL3's Wayland
# backend needs libxkbcommon >= 1.0 for xkb_keymap_key_get_mods_for_level. The
# game runs inside Steam's scout-on-soldier container, which still ships the
# xkbcommon that Debian buster froze in 2018, so loading the backend's symbols
# fails and SDL_Init aborts with the rather unhelpful "wayland not available".
#
# Letting SDL fall back to X11 is not an option on this machine: under XWayland
# the wheel arrives as fractional deltas that Terraria swallows, so scrolling
# does nothing and the hotbar is unusable.
#
# The library is copied out of the sniper runtime rather than taken from
# nixpkgs, because soldier's libc is 2.31 and anything nixpkgs builds wants
# GLIBC_2.38. Sniper's build needs only GLIBC_2.17, so it loads where the nix
# one cannot. It is also copied rather than symlinked: pressure-vessel binds
# preloaded files into the container individually, and a symlink into the store
# lands on paths the container never mounts.
#
# Staging it here rather than in the game directory is the whole point. Steam
# rewrites steamapps/common/Terraria on every update, which is why patching the
# game's own lib64 never survived more than one patch.
#
# Point Terraria's launch options at it (Steam keeps those across updates). The
# path is the one inside the sandbox, which is why it has no .var/app in it:
#
#   LD_PRELOAD=/home/kronberger/.local/share/steam-container-libs/x86_64/libxkbcommon.so.0 \
#     SDL_VIDEODRIVER=wayland SDL_AUDIODRIVER=alsa %command%
#
# LD_PRELOAD rather than LD_LIBRARY_PATH because pressure-vessel drops app
# library paths it cannot map into the container, but deliberately preserves
# preloads. SDL's later dlopen("libxkbcommon.so.0") then matches the SONAME of
# the already-loaded object instead of searching any directory.
{
  config,
  lib,
  ...
}: let
  cfg = config.steamFlatpak;
  appHome = "${config.home.homeDirectory}/.var/app/com.valvesoftware.Steam";
  runtimes = "${appHome}/.local/share/Steam/steamapps/common";
  dest = "${appHome}/.local/share/steam-container-libs/x86_64/libxkbcommon.so.0";
in {
  # Flatpak has no per-app launch arguments, so hosts that need client flags
  # get a desktop entry of the same id that shadows the exported one.
  options.steamFlatpak.extraArgs = lib.mkOption {
    type = with lib.types; listOf str;
    default = [];
    description = "Arguments passed to the Steam client on every launch.";
  };

  config = {
    xdg.desktopEntries."com.valvesoftware.Steam" = lib.mkIf (cfg.extraArgs != []) {
      name = "Steam";
      exec = "flatpak run com.valvesoftware.Steam ${lib.concatStringsSep " " cfg.extraArgs} %U";
      icon = "com.valvesoftware.Steam";
      terminal = false;
      categories = ["Network" "FileTransfer" "Game"];
      mimeType = ["x-scheme-handler/steam" "x-scheme-handler/steamlink"];
    };

    home.activation.steamContainerLibs = lib.hm.dag.entryAfter ["writeBoundary"] ''
      src=$(ls -d "${runtimes}"/SteamLinuxRuntime_sniper/sniper_platform_*/files/lib/x86_64-linux-gnu/libxkbcommon.so.0.0.0 2>/dev/null | sort | tail -1 || true)
      if [ -n "$src" ]; then
        $DRY_RUN_CMD install -Dm644 "$src" "${dest}"
      else
        echo "steam-container-libs: sniper runtime not installed, skipping libxkbcommon" >&2
      fi
    '';
  };
}
