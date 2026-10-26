{
  lib,
  pkgs,
  inputs,
  ...
}: let
  mkNixPak = inputs.nixpak.lib.nixpak {inherit lib pkgs;};

  # Ladybird in a bubblewrap sandbox, on the pattern of signal.nix. It is the
  # one browser here without a mature sandbox of its own: its WebContent and
  # RequestServer helpers run unconfined on Linux. It had no profile yet, so
  # config, data and state are private dirs under ~/.var/app mapped onto the
  # XDG locations inside, and nothing of it lands in the real home.
  ladybird = mkNixPak {
    config = {sloth, ...}: {
      imports = with inputs.nixpak.nixpakModules; [gui-base network];

      app.package = pkgs.ladybird;
      app.binPath = "bin/Ladybird";
      flatpak.appId = "org.ladybird.Ladybird";

      # gui-base bundles its own mesa; the host's driver matches the kernel
      # and is already in the store.
      gpu.provider = lib.mkForce "nixos";

      # Binds the host's /etc/localtime. Without it there is none in the
      # sandbox and every timestamp shows in UTC.
      timeZone.enable = true;

      bubblewrap = {
        bind.rw = [
          [(sloth.mkdir sloth.appConfigDir) sloth.xdgConfigHome]
          [(sloth.mkdir sloth.appDataDir) sloth.xdgDataHome]
          [(sloth.mkdir (sloth.concat' sloth.appDir "/state")) sloth.xdgStateHome]
          (sloth.concat' sloth.homeDir "/Downloads")
          # A private /tmp, see signal.nix.
          [(sloth.mkdir (sloth.concat' sloth.appCacheDir "/tmp")) "/tmp"]
        ];
      };
    };
  };
in {
  home.packages = [ladybird.config.env];
}
