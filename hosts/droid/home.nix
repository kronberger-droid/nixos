{
  config,
  lib,
  pkgs,
  inputs,
  stockNushell,
  ...
}: let
  # Hand off from the bash login shell to nushell, but only for an interactive
  # session on a real TTY — otherwise nu aborts with "STDIN is not a TTY". POSIX
  # so it's safe in .profile as well as .bashrc.
  #
  # When the handoff does NOT fire, say why on stderr: a silent landing in
  # bare bash is undebuggable from the phone, and the reason (no TTY vs. shell
  # not interactive) points at completely different culprits. Set NO_NU=1 to
  # skip the handoff (and the breadcrumb) and get plain bash on purpose.
  nuHandoff = ''
    if [ -z "''${NO_NU:-}" ]; then
      if [ -t 0 ]; then
        case $- in
          *i*) exec ${stockNushell}/bin/nu ;;
        esac
        echo "[droid] staying in bash: TTY stdin but shell is not interactive (\$0=$0, \$-=$-)" >&2
      else
        echo "[droid] staying in bash: stdin is not a TTY (stdin -> $(readlink /proc/$$/fd/0 2>/dev/null || echo unknown)); nu needs a TTY" >&2
      fi
    fi
  '';
in {
  # Read the changelog before changing this value
  home.stateVersion = "24.05";

  # Cached stock nushell — keeps the phone off the fork's on-device Rust build;
  # nushell.nix sees the non-fork version string and falls back to vi edit-mode.
  programs.nushell.package = stockNushell;

  # bash is the nix-on-droid login shell (see user.shell in nix-on-droid.nix);
  # it hands off to nushell for real interactive sessions. The `-t 0` guard is
  # the crux: only exec nu when stdin is an actual TTY, so nu never hits its
  # "STDIN is not a TTY" launch check that aborts the app at login. Non-TTY or
  # script invocations (and the failsafe/rescue path) stay in plain bash.
  #
  # Placed in BOTH profileExtra (.profile / .bash_profile — the login path
  # nix-on-droid actually uses) and initExtra (.bashrc — non-login interactive).
  # POSIX `case`/`[ -t 0 ]` so it's valid in .profile too; `exec` means whichever
  # fires first wins and the other is never reached.
  programs.bash = {
    enable = true;
    profileExtra = nuHandoff;
    initExtra = nuHandoff;
  };

  # HM master tracks 26.11 while nixpkgs unstable is still 26.05; both follow
  # unstable here, so this is a false positive (same as the desktop config).
  home.enableNixpkgsReleaseCheck = false;

  imports = [
    # base16 module provides the `scheme` option that helix.nix consumes;
    # ansi.nix derives config.ansi from it (also consumed by helix.nix)
    inputs.base16.homeManagerModule
    ../../modules/home-manager/theming/base16-scheme.nix
    ../../modules/home-manager/theming/ansi.nix

    # Portable leaf modules shared with the desktop/server configs
    ../../modules/home-manager/shell/nushell.nix
    ../../modules/home-manager/shell/git.nix
    ../../modules/home-manager/editors/helix.nix

    # Droid-local trimmed CLI tools (lean subset of shell/tools.nix)
    ./tools.nix
  ];

  # The repo isn't checked out at a fixed path on Android, so copy helix's
  # editable config from the store instead of out-of-store symlinking.
  helix.liveConfigPath = null;

  # Lean editor on mobile: Nix + Markdown + Rust only, no Typst/Python/GLSL.
  helix.minimal = true;

  # Copy Termux properties to ~/.termux/termux.properties
  # Termux requires a regular file, not a symlink
  home.activation.copyTermuxProperties = lib.hm.dag.entryAfter ["writeBoundary"] ''
    propertiesDst="$HOME/.termux/termux.properties"

    # Create .termux directory if it doesn't exist
    mkdir -p "$HOME/.termux"

    # Remove existing file/symlink if it exists
    if [ -e "$propertiesDst" ] || [ -L "$propertiesDst" ]; then
      $DRY_RUN_CMD rm -f "$propertiesDst"
    fi

    # Create the properties file with extra keys configuration
    $DRY_RUN_CMD cat > "$propertiesDst" << 'EOF'
### Extra keys configuration
extra-keys = [['ESC','TAB','/',';','|','UP','{'],['CTRL','ALT','&','"','LEFT','DOWN','RIGHT']]
EOF

    echo "Created termux.properties with extra keys configuration"
    echo "Please restart Termux to apply the extra keys"
  '';

  # Copy Nerd Font to ~/.termux/font.ttf
  # Termux requires a regular file, not a symlink
  home.activation.copyFont = lib.hm.dag.entryAfter ["writeBoundary"] ''
    fontPkg="${pkgs.nerd-fonts.jetbrains-mono}"
    fontDst="$HOME/.termux/font.ttf"

    # Find the first Regular TTF file in the nerd-fonts package
    fontSrc=$(${pkgs.findutils}/bin/find "$fontPkg/share/fonts" -name "*Regular.ttf" -type f | head -1)

    if [ -z "$fontSrc" ]; then
      # Fallback: find any TTF file if Regular is not found
      fontSrc=$(${pkgs.findutils}/bin/find "$fontPkg/share/fonts" -name "*.ttf" -type f | head -1)
    fi

    if [ -z "$fontSrc" ]; then
      echo "Error: No TTF font found in ${pkgs.nerd-fonts.jetbrains-mono}"
      exit 1
    fi

    # Create .termux directory if it doesn't exist
    mkdir -p "$HOME/.termux"

    # Copy font if it doesn't exist or has changed
    if [ ! -f "$fontDst" ] || ! ${pkgs.coreutils}/bin/sha1sum --status -c <(${pkgs.coreutils}/bin/sha1sum "$fontSrc" | ${pkgs.gnused}/bin/sed "s|$fontSrc|$fontDst|") 2>/dev/null; then
      $DRY_RUN_CMD cp -f "$fontSrc" "$fontDst"
      echo "Copied Nerd Font to ~/.termux/font.ttf"
      echo "Font source: $fontSrc"
      echo "Please restart Termux to apply the new font"
    fi
  '';
}
