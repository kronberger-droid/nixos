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
  # Each script binds its binaries to consts up top (`const WPCTL =
  # "@wireplumber@/bin/wpctl"`) rather than spelling `^@wireplumber@/bin/wpctl`
  # at the call site. That is what keeps the first claim above true: a bare
  # @var@ is not parseable nushell, so tree-sitter reads the whole line as an
  # error and then mis-highlights the rest of it, picking the next bare word as
  # the command. Inside a string the marker is just characters, the call sites
  # read as ordinary external commands, and substitution is unaffected either
  # way. Measured with tree-sitter over ./eww/nu: 96 parse errors before, 11
  # after. The 11 are all vpn.nu's `where on`, a row-condition shorthand no
  # released tree-sitter-nu parses yet. Valid nushell, so it stays.
  #
  # Installed names carry no extension and consumers go through `scriptPath`,
  # matching waybar's convention.
  script = name: vars:
    pkgs.replaceVars (./eww/nu + "/${name}.nu") (vars // {nu = pkgs.nushell;});

  scriptPath = name: "${config.xdg.configHome}/eww/scripts/${name}";

  # Every static config file goes through here rather than being referenced as
  # a bare ./eww/... path. A path inside a flake evaluates to a path inside the
  # flake's *source* store dir, so its string changes whenever anything in this
  # repo does; builtins.path copies the one file out, giving it a hash that
  # tracks only its own content. Invisible to xdg.configFile either way, but it
  # is what keeps eww.service's X-Restart-Triggers below honest, since those
  # trigger on the paths changing and would otherwise fire on every rebuild.
  # The scripts need no equivalent: replaceVars already builds each one into a
  # derivation of its own.
  file = p:
    builtins.path {
      path = p;
      name = baseNameOf p;
    };

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
    menu = {
      inherit utilLinux;
      inherit (pkgs) rofi;
    };
    bars = {inherit eww;};
    workspaces = {};
    # No vars beyond nushell itself: it reads /sys/class/power_supply.
    battery = {};
    backlight = {
      inherit eww;
      inherit (pkgs) brightnessctl;
    };
    network = {inherit (pkgs) iproute2;};
    vpn = {
      inherit eww;
      inherit (pkgs) systemd libnotify tailscale;
    };
    audio = {
      inherit eww;
      inherit (pkgs) wireplumber;
    };
    bluetooth = {
      inherit eww;
      inherit (pkgs) systemd bluez;
    };
    mpris = {inherit (pkgs) playerctl;};
    dnd = {
      inherit eww;
      inherit (pkgs) mako libnotify;
    };
    idle = {
      inherit eww;
      inherit (pkgs) systemd;
    };
    screenrec = {
      inherit eww utilLinux;
      inherit (pkgs) libnotify procps rofi slurp;
      wlScreenrec = pkgs.wl-screenrec;
    };
    scratchpad = terminalVars // {inherit (pkgs) zellij;};
    ncspot = terminalVars // {inherit (pkgs) zellij;};
    tui =
      terminalVars
      // {
        inherit utilLinux;
        dropkitten = dropkittenPkg;
        # dropkitten -t wants the emulator's name, not its path.
        terminalEmulator = config.terminal.emulator;
        inherit (pkgs) bash btop bluetuith calcurse networkmanager wiremix;
      };
  };

  widgets = ["bar" "modules" "clusters" "workspaces"];

  # _colors.scss is generated below, so it is not in this list.
  styles = ["_base" "_metrics" "bar" "workspaces" "dropdown" "tray-menu"];

  toAttrs = f: names: builtins.listToAttrs (map f names);
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
      "eww/eww.yuck".source = file ./eww/eww.yuck;
      "eww/eww.scss".source = file ./eww/eww.scss;

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
      value.source = file (./eww/widgets + "/${n}.yuck");
    })
    widgets
    // toAttrs (n: {
      name = "eww/styles/${n}.scss";
      value.source = file (./eww/styles + "/${n}.scss");
    })
    styles
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
  # it. The bars are opened by eww-bars.service below; the popups are opened on
  # demand by keybinds and by the bar's own buttons.
  systemd.user.services.eww = {
    Unit = {
      Description = "eww daemon";
      PartOf = ["graphical-session.target"];
      After = ["graphical-session.target"];
      # As home-manager's own waybar unit does: without a compositor there is
      # nothing to draw on, and the unit would restart-loop until it hit the
      # start limit.
      ConditionEnvironment = "WAYLAND_DISPLAY";
      # eww-bars binds to this unit, which covers the stop side but not the
      # start side, and a switch is the case where that matters: home-manager
      # stops a changed service and starts it again as two jobs rather than
      # restarting it, so the restart BindsTo would have propagated never
      # happens and the bars stay down until started by hand. Upholds is the
      # start side spelled out, and holds for every route into a restart
      # rather than just this one.
      Upholds = ["eww-bars.service"];
      # Without this a config-only rebuild reaches disk and nothing acts on
      # it, so the daemon keeps serving the previous config until it is
      # restarted by hand. Neither half of the usual pair fires: eww watches
      # the store paths its config files resolve to and a switch swaps the
      # symlinks above them, and home-manager restarts only units whose own
      # definition changed, which this one's never does. Listing the paths
      # makes a config change a unit change, which is the one signal both
      # sides do act on. Derived from xdg.configFile rather than written out,
      # so a widget or script added above joins it without being remembered.
      X-Restart-Triggers =
        map (f: toString f.source)
        (lib.attrValues
          (lib.filterAttrs (n: _: lib.hasPrefix "eww/" n) config.xdg.configFile));
    };
    Service = {
      ExecStart = "${eww}/bin/eww daemon --no-daemonize";
      # The scratchpad and ncspot popups spawn a terminal that inherits this
      # directory, so zellij opens in $HOME rather than wherever the daemon
      # happened to be started from.
      WorkingDirectory = config.home.homeDirectory;
      Restart = "on-failure";
    };
    Install.WantedBy = ["graphical-session.target"];
  };

  # A separate unit rather than the ExecStartPost this replaces: opening the
  # bars is no longer a one-shot. It has to keep watching, because a monitor
  # plugged in after login needs its own bar and niri has no reload to hang
  # that off.
  systemd.user.services.eww-bars = {
    Unit = {
      Description = "eww bars, one per output";
      PartOf = ["graphical-session.target"];
      # BindsTo, not just After: the ids this reconciles against live in the
      # daemon, so a restarted daemon must restart this too or it will think
      # bars are open that are not.
      BindsTo = ["eww.service"];
      # graphical-session.target belongs in here even though eww.service
      # already orders after it. A target implicitly orders itself after
      # everything it wants, so WantedBy alone gives
      # graphical-session.target -> after eww-bars -> after eww -> after
      # graphical-session.target, and systemd breaks that cycle by dropping
      # whichever job it likes, usually this one. Naming the target
      # explicitly replaces the implicit reverse ordering and the cycle goes
      # away. Every other unit here (swayidle, shikane, wlsunset) is shaped
      # the same way for the same reason.
      After = ["graphical-session.target" "eww.service"];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Service = {
      ExecStart = scriptPath "bars";
      Restart = "on-failure";
    };
    Install.WantedBy = ["graphical-session.target"];
  };
}
