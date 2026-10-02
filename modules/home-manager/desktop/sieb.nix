{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  sieb = inputs.sieb.packages.${pkgs.stdenv.hostPlatform.system}.default;
  # The example scripts the package ships; see the sieb flake's postInstall.
  examples = "${sieb}/share/sieb/examples";

  # Nerd Font glyphs, spelled as escapes so the source says which they are.
  glyph = code: builtins.fromJSON ''"\u${code}"'';

  # The colors rofi's colors.rasi derives from the base16 scheme, in the
  # same roles: background and background-alt at 90%, base0F the accent,
  # base0D and base09 the blue and red pills.
  s = config.scheme;
  background = "#${s.base00}e6";
  alternate = "#${s.base01}e6";
  foreground = "#${s.base05}";
  dark = "#${s.base00}";
  accent = "#${s.base0F}";
  active = "#${s.base0D}e6";
  urgent = "#${s.base09}e6";

  toml = pkgs.formats.toml {};
  common = {
    font = "JetBrainsMono Nerd Font";
    font-size = 13.333; # rofi's 10pt
    border-width = 0;
    separator-width = 0;
    spacing = 10;
    placeholder = "search...";
    counter = false;
  };

  # After rofi's launcher/style-2.rasi.
  launcherTheme = toml.generate "sieb-launcher.toml" (common
    // {
      width = 800;
      lines = 12;
      padding = 40;
      radius = 8;
      input-padding = 0;
      row-padding = 8.5;
      row-spacing = 5;
      row-radius = 4;
      message-padding = 8;
      scrollbar = true;
      colors = {
        inherit background;
        text = foreground;
        accent = foreground;
        prompt = foreground;
        placeholder = foreground;
        row = background;
        selected = foreground;
        selected-text = dark;
        match = accent;
        message = foreground;
        message-background = alternate;
        scrollbar = alternate;
        scrollbar-handle = foreground;
        button = alternate;
        button-text = foreground;
        button-selected = accent;
        button-selected-text = dark;
        backdrop = "#00000000";
      };
    });

  # After rofi's powermenu/style-1.rasi.
  powerTheme = toml.generate "sieb-power.toml" (common
    // {
      width = 400;
      lines = 6;
      padding = 20;
      radius = 12;
      input-padding = 10;
      row-padding = 10.5;
      row-spacing = 5;
      row-radius = 10;
      message-padding = 10;
      badge = glyph "f011";
      colors = {
        inherit background;
        text = foreground;
        accent = foreground;
        placeholder = foreground;
        selected = accent;
        selected-text = dark;
        match = accent;
        selected-match = foreground;
        badge = dark;
        badge-background = urgent;
        prompt = dark;
        prompt-background = active;
        message = foreground;
        message-background = alternate;
        backdrop = "#00000000";
      };
    });

  # sieb-pinentry's panel, after the power menu's: a small card with a lock
  # badge. No placeholder, which would read like a search field.
  pinentryTheme = toml.generate "sieb-pinentry.toml" (common
    // {
      width = 480;
      padding = 20;
      radius = 12;
      input-padding = 10;
      message-padding = 10;
      placeholder = "";
      badge = glyph "f023";
      colors = {
        inherit background;
        text = foreground;
        accent = foreground;
        badge = dark;
        badge-background = urgent;
        prompt = dark;
        prompt-background = active;
        message = foreground;
        message-background = alternate;
        backdrop = "#00000000";
      };
    });

  # The vault picker. Unlocking first, so the master password prompt (a
  # sieb-pinentry panel) is not opened under a picker that already holds
  # the keyboard. rbw.nu calls its tools bare, so they go on PATH here.
  rbw = pkgs.writeShellScript "sieb-rbw" ''
    export PATH=${lib.makeBinPath [
      config.programs.rbw.package
      pkgs.wtype
      pkgs.wl-clipboard
      pkgs.libnotify
    ]}:$PATH
    # Bound to a key, so a failed unlock says why rather than nothing.
    # Escape on the prompt is no failure worth a toast.
    if ! err=$(rbw unlock 2>&1); then
      case $err in
        *"pinentry cancelled"*) ;;
        *) notify-send -a rbw -u critical "Vault still locked" "$(printf %s "$err" | tr -d '<>&')" ;;
      esac
      exit 1
    fi
    exec ${sieb}/bin/sieb --config ${launcherTheme} --script ${examples}/rbw/rbw.nu
  '';

  # rofi's drun, run, filebrowser and window modes, labelled with the
  # glyphs rofi's display-* used.
  mode = code: script: "${glyph code}:${examples}/${script}";
  launcher = [
    "${sieb}/bin/sieb"
    "--config"
    "${launcherTheme}"
    "--script"
    (mode "f002" "launcher/drun.nu")
    "--script"
    (mode "f121" "launcher/run.nu")
    "--script"
    (mode "f07c" "launcher/files.nu")
    "--script"
    (mode "f2d0" "niri/window.nu")
  ];
  power = [
    "${sieb}/bin/sieb"
    "--config"
    "${powerTheme}"
    "--script"
    "${examples}/power/power.nu"
  ];
in {
  options.sieb.commands = {
    launcher = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      default = launcher;
      description = "argv of the app launcher, for compositor binds.";
    };
    power = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      default = power;
      description = "argv of the power menu, for compositor binds.";
    };
    rbw = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      default = ["${rbw}"];
      description = "argv of the Bitwarden picker, for compositor binds.";
    };
  };

  config = {
    # On PATH for dmenu use: `fd | sieb`.
    home.packages = [sieb];
    # So plain `sieb` looks like the launcher too, and the power theme is
    # at hand for `sieb --config ~/.config/sieb/power.toml`.
    xdg.configFile."sieb/config.toml".source = launcherTheme;
    xdg.configFile."sieb/power.toml".source = powerTheme;
    # Read by sieb-pinentry on its own, since rbw passes it no flags.
    xdg.configFile."sieb/pinentry.toml".source = pinentryTheme;
  };
}
