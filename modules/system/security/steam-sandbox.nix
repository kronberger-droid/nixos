# Keeps Steam, and every game it launches, out of the real home directory.
#
# nixpkgs already runs Steam in a bubblewrap FHS env, but that env binds all
# of /home, so a game or a compromised Steam client reads ~/.ssh, ~/.config
# and the vault as easily as Martin does. This puts a private directory over
# $HOME inside that same bwrap call and binds back only what Steam needs.
#
# Persistent rather than tmpfs: native games write saves and settings to
# ~/.local/share/<game> and ~/.config/<game>, and a tmpfs would drop them on
# every launch. $HOME keeps its real path, since Steam stores absolute paths
# (library folders, registry.vdf) and the Terraria LD_PRELOAD in
# home-manager/apps/steam.nix points at /home/<user>/.local/share.
#
# Flatpak Steam and a second uid were the alternatives. Both have to rebuild
# the Wayland, PipeWire and GPU plumbing, which the FHS env already gets for
# free through /run and /dev. What this does not cover: D-Bus, the Wayland
# socket and the network all stay reachable, so it contains filesystem
# damage, not a game talking to the session bus. That includes the agent
# and keyring sockets in $XDG_RUNTIME_DIR: hiding ~/.ssh does not stop a
# process from asking the agent to sign, the same gap agent-sandbox.nix
# describes.
#
# The bind arguments land after the env's own auto-mounts of / (see
# build-fhsenv-bubblewrap), so the private home wins over the /home bind, and
# bwrap still resolves the later sources from the real root even though
# their destinations are hidden by then.
#
# steam-run shares extraBwrapArgs with steam, so the sandbox keys off the
# name it was invoked by: bin/steam-run from PATH, or the store script's own
# name when called directly. steam-run exists to run binaries from wherever the
# caller is, and hiding the home it was pointed at would break exactly that.
#
# The cd is for bwrap's --chdir "$(pwd)", which is built after these
# commands run: launched from a directory under the hidden home, bwrap
# would otherwise fail to chdir and refuse to start.
{...}: {
  nixpkgs.overlays = [
    (final: prev: {
      steam = prev.steam.override (old: {
        extraPreBwrapCmds =
          (old.extraPreBwrapCmds or "")
          + ''
            steam_sandbox=()
            case "''${0##*/}" in
              steam-run | *-steam-run-*) ;;
              *)
                steam_home="$HOME/.local/share/steam-home"
                mkdir -p "$steam_home" "$HOME/.local/share/Steam" "$HOME/.steam" \
                  "$HOME/.local/share/steam-container-libs"
                cd "$HOME"
                steam_sandbox=(
                  --bind "$steam_home" "$HOME"
                  --bind "$HOME/.local/share/Steam" "$HOME/.local/share/Steam"
                  # Holds the login token and the client registry.
                  --bind "$HOME/.steam" "$HOME/.steam"
                  --ro-bind "$HOME/.local/share/steam-container-libs" "$HOME/.local/share/steam-container-libs"
                  # Cursor themes, so the client does not fall back to the
                  # default X cursor.
                  --ro-bind-try "$HOME/.icons" "$HOME/.icons"
                  --ro-bind-try "$HOME/.local/share/icons" "$HOME/.local/share/icons"
                )
                ;;
            esac
          '';
        extraBwrapArgs = (old.extraBwrapArgs or []) ++ [''"''${steam_sandbox[@]}"''];
      });
    })
  ];
}
