# Lean "media box" user: the full niri desktop (waybar, rofi, mako, nemo,
# theming, terminals) but none of the development tooling or personal apps.
#
# Contrast with kronberger.nix, which imports `../.` (the whole module tree:
# shell + editors + terminals + desktop + apps + theming). Here we cherry-pick
# only the desktop-facing modules, so no dev-tools.nix (rust/python), no
# neovim, no claude/ai, no aerc/syncthing/etc.
{
  pkgs,
  lib,
  inputs,
  host,
  isNotebook,
  primaryCompositor,
  ...
}: let
  dropkittenPkg = inputs.dropkitten.packages.${pkgs.stdenv.hostPlatform.system}.dropkitten;
  # Stock nushell straight from nixpkgs, bypassing the global helix-mode overlay
  # (modules/shared/nushell-overlay.nix). The overlay rebuilds nushell from our
  # fork's source; this media box doesn't need the helix edit-mode, so use the
  # prebuilt cache binary instead. nushell.nix detects the non-fork build and
  # falls back to vi edit-mode automatically.
  stockNushell = inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system}.nushell;
in {
  home-manager = {
    extraSpecialArgs = {
      inherit inputs host isNotebook dropkittenPkg primaryCompositor;
    };
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    users.media = {
      imports = [
        ../desktop # sway, waybar, rofi, mako (session-services), udiskie, kanshi, xdg
        ../theming # base16 colors, fonts
        ../terminals # rio/kitty/zellij + the terminal.* options the desktop reads
        ../editors/helix.nix # helix only (the EDITOR); no neovim, no dev-tools
        ../shell/nushell.nix # login shell config
      ];

      # Drop niri's home config entirely on this host: niri-flake validates the
      # generated KDL by running the niri binary, which would pull in the
      # built-from-source niri-unstable fork. Without it, sway (prebuilt from
      # cache) is the only compositor here. System-side niri is disabled in
      # hosts/mediaBox/configuration.nix.
      disabledModules = [../desktop/niri.nix];

      # kitty (prebuilt) instead of rio (built from rio-upstream's flake).
      # terminals/rio.nix hard-enables rio, so disable it explicitly — selecting
      # kitty below is not enough to keep rio out of the closure.
      terminal.emulator = "kitty";
      programs.rio.enable = lib.mkForce false;
      compositor.primary = primaryCompositor;

      # Stock nushell (see stockNushell above) — no source rebuild on this host.
      programs.nushell.package = stockNushell;

      # Drop the bitwarden-desktop launcher (Mod+Shift+P) — this box uses the
      # browser extension instead. Unbinding it removes the only reference to
      # ${pkgs.bitwarden-desktop}, so its EOL electron-39 closure goes too (the
      # permittedInsecurePackages allowance in configuration.nix is dropped).
      # sway.nix sets keybindings via mkOptionDefault, so null just wins here.
      wayland.windowManager.sway.config.keybindings."Mod4+Shift+p" = lib.mkForce null;

      # Appliance autostart: launch firefox on login. config.startup is a list,
      # so this concatenates with sway.nix's entries (transparency, autotiling)
      # rather than replacing them. always = false → only on initial start, not
      # on every `swaymsg reload`. Mod+Shift+S still opens it manually.
      wayland.windowManager.sway.config.startup = [
        {
          command = "${pkgs.firefox}/bin/firefox";
          always = false;
        }
      ];

      home = {
        username = "media";
        homeDirectory = "/home/media";
        packages = with pkgs; [
          nemo-with-extensions # GUI file manager (Mod+Shift+N)
          firefox # browser (Mod+Shift+S in sway)
        ];
        stateVersion = "25.05";
        # HM master's release string runs ahead of nixpkgs unstable; both track
        # unstable so there's no real mismatch — silence the false warning.
        enableNixpkgsReleaseCheck = false;
      };

      programs.home-manager.enable = true;
    };
  };
}
