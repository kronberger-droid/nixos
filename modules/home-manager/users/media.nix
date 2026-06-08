# Lean "media box" user: the full niri desktop (waybar, rofi, mako, nemo,
# theming, terminals) but none of the development tooling or personal apps.
#
# Contrast with kronberger.nix, which imports `../.` (the whole module tree:
# shell + editors + terminals + desktop + apps + theming). Here we cherry-pick
# only the desktop-facing modules, so no dev-tools.nix (rust/python), no
# neovim, no claude/ai, no aerc/syncthing/etc.
{
  pkgs,
  inputs,
  host,
  isNotebook,
  primaryCompositor,
  ...
}: let
  dropkittenPkg = inputs.dropkitten.packages.${pkgs.stdenv.hostPlatform.system}.dropkitten;
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
        ../desktop # niri, sway, waybar, rofi, mako (session-services), udiskie, kanshi, xdg
        ../theming # base16 colors, fonts
        ../terminals # rio/kitty/zellij + the terminal.* options the desktop reads
        ../editors/helix.nix # helix only (the EDITOR); no neovim, no dev-tools
        ../shell/nushell.nix # login shell config
      ];

      # rio terminal; niri as the launched compositor (sway config still built).
      terminal.emulator = "rio";
      compositor.primary = primaryCompositor;

      home = {
        username = "media";
        homeDirectory = "/home/media";
        packages = with pkgs; [
          nemo-with-extensions # GUI file manager (Mod+Shift+N in niri)
          helium # browser (Mod+Shift+S in niri)
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
