{
  dropkittenPkg,
  config,
  pkgs,
  lib,
  ...
}: let
  # Helper scripts live as real files under ./eww/nu/ rather than inline Nix
  # strings, exactly as waybar.nix does it: they stay syntax-highlighted and
  # lintable (`nu -n --ide-check 20 <file>`) and need no ''${} escaping. Store
  # paths arrive as replaceVars placeholders (@nu@, @eww@, …), a plain textual
  # substitution, and replaceVars fails the build both on an unfilled @var@ and
  # on an unused attr, so the table below cannot drift from the scripts.
  #
  # Installed names carry no extension and consumers go through `scriptPath`,
  # matching waybar's convention.
  script = name: vars:
    pkgs.replaceVars (./eww/nu + "/${name}.nu") (vars // {nu = pkgs.nushell;});

  scriptPath = name: "${config.xdg.configHome}/eww/scripts/${name}";

  eww = config.programs.eww.package;

  # setsid, for the scripts' detach helpers. Nushell has no `&`.
  utilLinux = pkgs.util-linux;

  # config.terminal.* drive the two zellij popups, the same three values
  # waybar.nix passes to its scratchpad and ncspot helpers.
  terminalVars = {
    terminalBin = config.terminal.bin;
    terminalAppIdFlag = config.terminal.appIdFlag;
    terminalExecFlag = config.terminal.execFlag;
  };

  scripts = {
    menu = {inherit (pkgs) rofi;};
    workspaces = {};
    network = {inherit (pkgs) iproute2;};
    vpn = {inherit eww; inherit (pkgs) systemd libnotify tailscale;};
    audio = {inherit eww; inherit (pkgs) wireplumber;};
    bluetooth = {inherit eww; inherit (pkgs) systemd bluez;};
    mpris = {inherit (pkgs) playerctl;};
    dnd = {inherit eww; inherit (pkgs) mako libnotify;};
    idle = {inherit eww; inherit (pkgs) systemd;};
    screenrec = {
      inherit eww utilLinux;
      inherit (pkgs) libnotify procps rofi slurp;
      wlScreenrec = pkgs.wl-screenrec;
    };
    scratchpad = terminalVars // {inherit (pkgs) zellij;};
    ncspot = terminalVars // {inherit (pkgs) zellij;};
    tui = {inherit utilLinux; dropkitten = dropkittenPkg;};
  };

  widgets = ["bar" "modules" "clusters" "workspaces"];

  # _colors.scss is generated below, so it is not in this list.
  styles = ["_base" "_metrics" "bar" "workspaces" "dropdown"];

  toAttrs = f: names: builtins.listToAttrs (map f names);

  # systemd calls ExecStartPost directly, with no shell, so `sleep 1 && eww
  # open bar` was passed to sleep as arguments and failed the unit. A script
  # keeps the retry readable and avoids guessing how long the socket takes:
  # the daemon counts as active the moment the process starts, but its IPC
  # socket appears a little later.
  openBar = pkgs.writeShellScript "eww-open-bar" ''
    for _ in $(seq 1 25); do
      ${eww}/bin/eww open bar && exit 0
      sleep 0.2
    done
    exit 1
  '';
in {
  programs.eww = {
    enable = true;
    package = pkgs.eww;
    # No configDir / yuckConfig / scssConfig here: the config is assembled from
    # the xdg.configFile entries below, because scripts/ and _colors.scss are
    # generated and a whole-directory symlink cannot mix generated files in.
  };

  xdg.configFile =
    {
      "eww/eww.yuck".source = ./eww/eww.yuck;
      "eww/eww.scss".source = ./eww/eww.scss;

      # The shared palette, the direct equivalent of rofi/shared/colors.rasi.
      # Generated so a scheme change repaints eww along with mako and waybar.
      "eww/styles/_colors.scss".text = with config.scheme; ''
        // Generated from modules/home-manager/theming/base16-scheme.nix.
        // Edit the scheme, not this file.

        $base00: #${base00}; // background
        $base01: #${base01}; // alternate background
        $base02: #${base02}; // selection
        $base03: #${base03}; // muted
        $base04: #${base04}; // dark foreground
        $base05: #${base05}; // foreground
        $base08: #${base08}; // error
        $base09: #${base09}; // urgent
        $base0A: #${base0A}; // warning
        $base0B: #${base0B}; // green
        $base0C: #${base0C}; // cyan
        $base0D: #${base0D}; // active / blue
        $base0E: #${base0E}; // magenta
        $base0F: #${base0F}; // accent, and rofi's `selected`

        // rofi composites alpha into the hex (base00E6 = 90%). GTK CSS has no
        // hex-with-alpha, so the translucent variants are spelled out.
        $panel-bg: rgba(30, 30, 30, 0.9);
        $alt-bg: rgba(44, 47, 51, 0.9);
        $active-bg: rgba(108, 153, 186, 0.9);
        $urgent-bg: rgba(172, 65, 66, 0.9);
        $accent-bg: rgba(138, 129, 119, 0.9);
      '';
    }
    // toAttrs (n: {
      name = "eww/widgets/${n}.yuck";
      value.source = ./eww/widgets + "/${n}.yuck";
    }) widgets
    // toAttrs (n: {
      name = "eww/styles/${n}.scss";
      value.source = ./eww/styles + "/${n}.scss";
    }) styles
    // lib.mapAttrs' (n: vars:
      lib.nameValuePair "eww/scripts/${n}" {
        executable = true;
        source = script n vars;
      })
    scripts;

  home.packages = [
    # playerctl backs the mpris module. waybar used waybar-mpris, which is a
    # singleton with an IPC socket and so cannot serve two bars at once.
    pkgs.playerctl
  ];

  # eww is a daemon: one server per config dir, and windows are opened against
  # it. The bar is opened here; the popups are opened on demand by keybinds and
  # by the bar's own buttons.
  systemd.user.services.eww = {
    Unit = {
      Description = "eww daemon";
      PartOf = ["graphical-session.target"];
      After = ["graphical-session.target"];
      # As home-manager's own waybar unit does: without a compositor there is
      # nothing to draw on, and the unit would restart-loop until it hit the
      # start limit.
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Service = {
      ExecStart = "${eww}/bin/eww daemon --no-daemonize";
      ExecStartPost = openBar;
      # The scratchpad and ncspot popups spawn a terminal that inherits this
      # directory, so zellij opens in $HOME rather than wherever the daemon
      # happened to be started from.
      WorkingDirectory = config.home.homeDirectory;
      Restart = "on-failure";
    };
    Install.WantedBy = ["graphical-session.target"];
  };
}
