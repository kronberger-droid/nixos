{
  dropkittenPkg,
  config,
  osConfig ? null,
  pkgs,
  lib,
  ...
}: let
  # Helper scripts live as real files under ./ironbar/nu/ rather than inline
  # Nix strings: they stay syntax-highlighted and lintable (`nu -n --ide-check
  # 20 <file>`) and need no ''${} escaping. Store paths arrive as replaceVars
  # placeholders (@nu@, @bridge@, …), a plain textual substitution, and
  # replaceVars fails the build both on an unfilled @var@ and on an unused
  # attr, so the table below cannot drift from the scripts.
  #
  # Each script binds its binaries to consts up top (`const WPCTL =
  # "@wireplumber@/bin/wpctl"`) rather than spelling `^@wireplumber@/bin/wpctl`
  # at the call site. A bare @var@ is not parseable nushell, so tree-sitter
  # reads the whole line as an error and mis-highlights the rest of it; inside
  # a string the marker is just characters.
  #
  # The shebang runs nu through `env -S` because the kernel hands everything
  # after the interpreter to it as one argv entry, and nu rejects
  # "-n --no-std-lib" packed that way. --no-std-lib is worth the extra exec:
  # it took startup from ~11 ms to ~7 ms on 0.116, which every poll pays.
  #
  # Executable, since the bar and the helpers run each other by store path.
  script = name: vars:
    pkgs.replaceVarsWith {
      src = ./ironbar/nu + "/${name}.nu";
      replacements =
        vars
        // {
          inherit (pkgs) coreutils;
          nu = pkgs.nushell;
        };
      isExecutable = true;
    };

  # Installed names carry no extension. niri's binds reach two of them here.
  scriptPath = name: "${config.xdg.configHome}/ironbar/scripts/${name}";

  # setsid for lib.nu's `detach`, flock for audio.nu's throttles.
  utilLinux = pkgs.util-linux;

  # The helpers several scripts share: `detach` and `spawn-terminal`. Built
  # straight through replaceVars rather than `script`, which would hand it @nu@
  # and @coreutils@ it has no use for, and never installed under scripts/: each
  # consumer gets the store path as @barLib@ and `use`s that, so a script finds
  # it however it was started. That `use` line is the one placeholder nushell
  # resolves at parse time, so an --ide-check on the source tree reports the
  # module as not found there. flake.nix's nu-parse check points it at a
  # substituted copy instead.
  barLib = pkgs.replaceVars ./ironbar/nu/lib.nu {
    inherit utilLinux;
    terminalBin = config.terminal.bin;
    terminalAppIdFlag = config.terminal.appIdFlag;
    terminalExecFlag = config.terminal.execFlag;
  };

  bridge = script "bridge" {inherit (pkgs) ironbar;};
  drawer = script "drawer" {inherit (pkgs) ironbar;};

  scripts = {
    # sieb.commands are argv lists; one wrapper each so menu.nu gets a path.
    menu = {
      inherit barLib;
      siebLauncher = pkgs.writeShellScript "sieb-launcher" "exec ${lib.escapeShellArgs config.sieb.commands.launcher}";
      siebPower = pkgs.writeShellScript "sieb-power" "exec ${lib.escapeShellArgs config.sieb.commands.power}";
    };
    # Reads /sys/class/power_supply itself.
    battery = {inherit bridge;};
    backlight = {
      inherit bridge;
      inherit (pkgs) brightnessctl;
    };
    network = {
      inherit bridge;
      inherit (pkgs) iproute2;
    };
    vpn = {
      inherit bridge;
      inherit (pkgs) systemd libnotify tailscale ironbar;
      on = "#${config.scheme.base0B}";
      off = "#${config.scheme.base03}";
    };
    audio = {
      inherit bridge drawer barLib utilLinux;
      inherit (pkgs) wireplumber;
    };
    bluetooth = {
      inherit bridge;
      inherit (pkgs) systemd bluez;
    };
    mpris = {inherit (pkgs) playerctl;};
    dnd = {
      inherit bridge;
      inherit (pkgs) mako libnotify;
    };
    idle = {
      inherit bridge;
      inherit (pkgs) systemd;
    };
    screenrec = {
      inherit bridge barLib;
      inherit (pkgs) libnotify procps slurp;
      # sieb.commands.prompt is an argv list; screenrec.nu wants one path.
      siebPrompt = pkgs.writeShellScript "sieb-prompt" "exec ${lib.escapeShellArgs config.sieb.commands.prompt} \"$@\"";
      wlScreenrec = pkgs.wl-screenrec;
    };
    scratchpad = {
      inherit barLib;
      inherit (pkgs) zellij;
    };
    spotify = {
      inherit barLib;
      spotifyPlayer = lib.getExe config.programs.spotify-player.package;
      spotifyDevice = config.programs.spotify-player.settings.device.name;
    };
    tui = {
      inherit barLib;
      dropkitten = dropkittenPkg;
      # dropkitten -t wants the emulator's name, not its path.
      terminalEmulator = config.terminal.emulator;
      inherit (pkgs) bottom bluetui calcurse wiremix;
      # impala needs iwd without NetworkManager on top; see the system's
      # networking/iwd.nix. nmtui keeps the colours it always had.
      wifiTui =
        if (osConfig.networking.iwdSwap.stage or "off") == "standalone"
        then "${pkgs.impala}/bin/impala"
        else
          pkgs.writeShellScript "nmtui-connect" ''
            NEWT_COLORS='root=white,black:window=white,black:border=blue,black:listbox=white,black:actlistbox=black,blue:label=white,black:title=brightblue,black:button=white,black:actbutton=black,blue:compactbutton=white,black:checkbox=white,black:actcheckbox=black,blue:entry=white,black:textbox=white,black' exec ${pkgs.networkmanager}/bin/nmtui connect
          '';
    };
  };

  run = name: args: "${scriptPath name} ${args}";

  # A label fed by a status script through bridge.nu. Text and tooltip are
  # ironvars the bridge sets; `name` is what it targets for the class swap.
  # The poll is a `{{ms:…}}` script that pushes and prints nothing, so the
  # label shows the ironvar alone, and a toggle pushing between polls lands at
  # once. Short-lived on purpose: a watch script would outlive `ironbar
  # reload`, which does not reap them.
  status = name: ms: extra:
    {
      type = "label";
      inherit name;
      class = "mod";
      label = "#${name}_text{{${toString ms}:${run name "push"}}}";
      tooltip = "#${name}_tip";
    }
    // extra;
  # The two scripts that stream: they print a record per niri or MPRIS event.
  streamed = name: extra:
    status name 0 extra
    // {label = "#${name}_text{{watch:${bridge} listen ${name} ${scriptPath name}}}";};

  # Hooks every member of a drawer carries; see drawer.nu for the debounce.
  hover = d: {
    on_mouse_enter = "${drawer} enter ${d}";
    on_mouse_exit = "${drawer} leave ${d}";
  };
  # A drawer child: shown while the drawer is open, sliding out leftward from
  # the handle as eww's `slideleft` revealer did. 100ms rather than eww's
  # 300ms, which read as lag rather than motion.
  member = d: m:
    m
    // hover d
    // {
      show_if = "#${d}_open";
      transition_type = "slide_start";
      transition_duration = 100;
    };
  handle = d: glyph:
    {
      type = "label";
      name = "${d}-handle";
      class = "handle";
      label = glyph;
      on_click_left = "${drawer} pin ${d}";
    }
    // hover d;

  sep = {
    type = "label";
    class = "sep";
    label = "|";
  };
  # The power group's trailing separator hides with the group: on a desktop
  # both modules are absent and the two separators would collapse into an
  # empty "| |".
  powerGroup = ''for f in /sys/class/power_supply/BAT* /sys/class/backlight/*; do [ -e "$f" ] && exit 0; done; exit 1'';

  button = class: glyph: cmd: {
    type = "custom";
    inherit class;
    bar = [
      {
        type = "button";
        label = glyph;
        on_click = "!${cmd}";
      }
    ];
  };

  # One row of the VPN popup: a state dot and the name, left-aligned in a
  # box the way eww's vpn-menu-panel lays them out.
  dropRow = class: dot: text: cmd: {
    type = "button";
    inherit class;
    on_click = "!${cmd}";
    widgets = [
      {
        type = "box";
        halign = "start";
        widgets = [
          {
            type = "label";
            class = "dot";
            label = dot;
          }
          {
            type = "label";
            label = text;
          }
        ];
      }
    ];
  };
  # In vpn.nu's `entries` order, which is what numbers the dot ironvars.
  vpns = ["Tailscale" "PIA VPN" "TU Wien VPN"];
  vpnRow = i: name: dropRow "drop-row" "#vpn_dot_${toString i}" name (run "vpn" "toggle '${name}'");

  wpctl = "${pkgs.wireplumber}/bin/wpctl";

  statusNames = ["scratchpad" "screenrec" "idle" "dnd" "bluetooth" "audio" "mpris" "network" "vpn" "battery" "backlight"];

  bar = {
    position = "top";
    height = 30;
    anchor_to_edges = true;

    start = [
      (button "menu" "" (run "menu" "launcher"))
      {
        type = "workspaces";
        sort = "index";
      }
      (streamed "scratchpad" {on_click_left = run "scratchpad" "toggle";})
    ];

    end = [
      (status "screenrec" 30000 {
        show_if = "#screenrec_shown";
        on_click_left = run "screenrec" "toggle";
      })

      # Toggles drawer: idle inhibit and DND behind the handle.
      (member "toggles" (status "idle" 30000 {on_click_left = run "idle" "toggle";}))
      (member "toggles" (status "dnd" 30000 {on_click_left = run "dnd" "toggle";}))
      (handle "toggles" "")
      sep

      (status "bluetooth" 5000 {
        on_click_left = run "tui" "bluetooth";
        on_click_right = run "bluetooth" "toggle";
      })

      # Volume: the slider is the audio drawer's only member, revealed by
      # hovering the readout and held out through a drag by audio.nu.
      (member "audio" {
        type = "custom";
        class = "volume";
        bar = [
          {
            type = "slider";
            length = 100;
            max = 100;
            show_label = false;
            value = "2000:${wpctl} get-volume @DEFAULT_AUDIO_SINK@ | ${pkgs.gawk}/bin/awk '{print int($2 * 100)}'";
            on_change = "!${run "audio" "set"} $0";
          }
        ];
      })
      (status "audio" 2000 ({
          on_click_left = run "tui" "audio";
          on_click_right = run "audio" "toggle-mute";
          on_scroll_up = run "audio" "scroll up";
          on_scroll_down = run "audio" "scroll down";
        }
        // hover "audio"))

      (streamed "mpris" {
        show_if = "#mpris_shown";
        on_click_left = run "mpris" "toggle";
        on_click_right = run "mpris" "next";
      })
      sep
      (status "network" 5000 {on_click_left = run "tui" "wifi";})

      # VPN: a popup in place of eww's vpn-menu window.
      {
        type = "custom";
        name = "vpn";
        class = "mod";
        tooltip = "#vpn_tip";
        on_click_right = run "vpn" "disconnect-all";
        bar = [
          {
            type = "button";
            label = "󰖂#vpn_text{{15000:${run "vpn" "push"}}}";
            on_click = "popup:toggle";
          }
        ];
        popup = [
          {
            type = "box";
            orientation = "v";
            class = "dropdown";
            widgets =
              lib.imap0 vpnRow vpns
              ++ [(dropRow "drop-row danger" "✕" "disconnect all" (run "vpn" "disconnect-all"))];
          }
        ];
      }
      sep

      (status "battery" 30000 {show_if = "#battery_shown";})
      (status "backlight" 5000 {
        show_if = "#backlight_shown";
        on_scroll_up = run "backlight" "scroll up";
        on_scroll_down = run "backlight" "scroll down";
      })
      (sep // {show_if = powerGroup;})
      {
        type = "sys_info";
        format = ["{cpu_percent:1}% " "{memory_percent:1.0}% " "{temp_c:1.0}°C "];
        on_click_left = run "tui" "monitor";
      }
      sep

      # Tray drawer: spotify button and the tray behind the handle.
      (member "tray" (button "mod spotify-btn" "" (scriptPath "spotify")))
      # eww's systray: icon-size 14, spacing 10.
      (member "tray" {
        type = "tray";
        icon_size = 14;
      })
      (handle "tray" "")

      {
        type = "clock";
        format = "%e %b %Y %H:%M";
        disable_popup = true;
        on_click_left = run "tui" "calendar";
      }
      (button "power" "" (run "menu" "power"))
    ];
  };

  configFile =
    {
      # Every ironvar the config reads, so nothing renders as a literal
      # `#name` before its first push.
      ironvar_defaults =
        lib.genAttrs (lib.concatMap (d: map (k: "${d}_${k}") ["open" "hover" "pinned" "busy"]) ["toggles" "tray" "audio"]) (_: "false")
        // lib.genAttrs (lib.concatMap (n: ["${n}_text" "${n}_tip" "${n}_class"]) statusNames) (_: "")
        // lib.genAttrs (map (n: "${n}_shown") statusNames) (_: "false")
        // lib.genAttrs (lib.imap0 (i: _: "vpn_dot_${toString i}") vpns) (_: "");
    }
    // bar;

  # A port of eww's bar.scss, _metrics.scss and workspaces.scss, values
  # copied rather than re-derived so the two bars can be compared side by
  # side. The translucent backgrounds are eww.nix's spelled-out rgba ones.
  style = with config.scheme; ''
    /* Generated from modules/home-manager/theming/base16-scheme.nix. */
    @define-color base00 #${base00};
    @define-color base02 #${base02};
    @define-color base03 #${base03};
    @define-color base05 #${base05};
    @define-color base08 #${base08};
    @define-color base0A #${base0A};
    @define-color base0B #${base0B};
    @define-color base0F #${base0F};
    @define-color panel_bg rgba(30, 30, 30, 0.9);
    @define-color accent_bg rgba(138, 129, 119, 0.9);
    @define-color urgent_bg rgba(172, 65, 66, 0.9);

    /* Symbols first, as eww's bar.scss has it, so glyphs present in both
       come from the symbols font. */
    * {
      all: unset;
      font-family: "Symbols Nerd Font Mono", "JetBrains Mono Nerd Font";
      font-size: 14px;
      color: @base05;
    }

    .background, #bar {
      background-color: transparent;
    }
    #bar {
      padding: 0 2px;
    }

    /* bar-pill: menu, clock, power. eww centres a 26px pill in the 30px
       bar; ironbar stretches every module to the bar's height and GTK CSS
       has no valign, so the 2px above and below is margin. */
    .menu, .clock, .power {
      background-color: @accent_bg;
      border-radius: 15px;
      padding: 0 10px;
      margin: 2px 5px;
      min-height: 26px;
    }

    /* bar-module: flat, no background. */
    .mod, .tray, .battery, .handle {
      padding: 0 5px;
      margin: 0 5px;
      min-height: 26px;
    }

    /* GTK4 places glyphs at fractional advances where eww's GTK3 rounds
       them to whole pixels, so the same string sets slightly wider. Only the
       clock is long enough for it to show: ~6px over its 17 characters. The
       fix proper is the gtk-hint-font-metrics setting, which GTK4 has no CSS
       property for and would change every GTK4 app. */
    .clock label { letter-spacing: -0.4px; }

    .mod:hover, .menu:hover label, .power:hover label, .clock:hover label {
      color: @base03;
    }

    /* No margin: sys_info's labels already sit ~12px apart, which with the
       padding comes to the 22px eww's separate cpu/memory/temp modules have. */
    .sysinfo .item {
      padding: 0 5px;
      min-height: 26px;
    }

    .sep {
      padding: 0 2px;
      margin: 0;
      color: @base03;
    }

    .handle { color: @base03; }
    .handle:hover, .handle.pinned { color: @base05; }

    #screenrec.recording {
      background-color: @urgent_bg;
      border-radius: 15px;
      padding: 0 10px;
      margin: 2px 5px;
    }

    #scratchpad {
      border-radius: 15px;
      padding: 0 10px;
      margin: 2px 5px;
      min-height: 26px;
    }
    #scratchpad.open { background-color: @accent_bg; }
    #scratchpad.closed { background-color: @panel_bg; }

    .tray .item { margin: 0 5px; }
    .tray .item:first-child { margin-left: 0; }
    .tray .item:last-child { margin-right: 0; }

    .critical, .critical label { color: @base08; }
    .warning, .warning label { color: @base0A; }
    .spotify-btn label { color: @base0B; }

    /* 3px: eww's group shrinks to its 24px buttons and centres. */
    .workspaces {
      background-color: @panel_bg;
      border-radius: 15px;
      margin: 3px 5px;
    }
    .workspaces .item {
      border-radius: 15px;
      padding: 0 10px;
      min-width: 32px;
      min-height: 24px;
    }
    .workspaces .item:hover { background-color: @base02; }
    .workspaces .item.focused { background-color: @accent_bg; }
    .workspaces .item.urgent { color: @base08; }

    .volume { margin: 0 0 0 5px; }
    .volume trough {
      min-width: 100px;
      min-height: 4px;
      border-radius: 2px;
      background-color: @panel_bg;
    }
    .volume highlight {
      border-radius: 2px;
      background-color: @base05;
    }
    .volume slider {
      min-width: 12px;
      min-height: 12px;
      margin: -4px 0;
      border-radius: 6px;
      background-color: @base0F;
    }

    tooltip {
      background-color: @base00;
      border-radius: 6px;
      padding: 4px 8px;
    }

    /* eww's dropdown.scss. Popups are not bar text, so they keep _base.scss's
       13px JetBrains Mono rather than the bar's symbols-first 14px. */
    .popup {
      background-color: @base00;
      border-radius: 8px;
      padding: 8px;
      min-width: 180px;
    }
    .popup * {
      font-family: "JetBrains Mono Nerd Font";
      font-size: 13px;
    }
    .drop-row {
      border-radius: 6px;
      padding: 8px;
      margin-bottom: 4px;
    }
    .drop-row.danger { margin-bottom: 0; }
    .drop-row:hover { background-color: @base02; }
    .drop-row .dot { margin-right: 10px; }
    .drop-row.danger label { color: @base08; }
  '';
in {
  home.packages = [
    pkgs.ironbar
    # playerctl backs the mpris module and is handy from a shell.
    pkgs.playerctl
  ];

  xdg.configFile =
    {
      "ironbar/config.json".text = builtins.toJSON configFile;
      "ironbar/style.css".text = style;
    }
    // lib.mapAttrs' (n: vars:
      lib.nameValuePair "ironbar/scripts/${n}" {
        source = script n vars;
      })
    scripts;

  systemd.user.services.ironbar = {
    Unit = {
      Description = "ironbar";
      PartOf = ["graphical-session.target"];
      # graphical-session.target is named explicitly, not left implicit: a
      # target orders itself after everything it wants, and with WantedBy
      # alone that ordering can form a cycle systemd breaks by dropping
      # whichever job it likes.
      After = ["graphical-session.target"];
      # Without a compositor there is nothing to draw on, and the unit would
      # restart-loop until it hit the start limit.
      ConditionEnvironment = "WAYLAND_DISPLAY";
      # The CSS hot-reloads, the config does not, and home-manager restarts
      # only units whose own definition changed. Listing the config's paths
      # makes a config change a unit change. Derived from xdg.configFile so a
      # script added above joins without being remembered.
      X-Restart-Triggers =
        map (f: toString f.source)
        (lib.attrValues
          (lib.filterAttrs (n: _: lib.hasPrefix "ironbar/" n) config.xdg.configFile));
    };
    Service = {
      ExecStart = "${pkgs.ironbar}/bin/ironbar";
      # The scratchpad popup spawns a terminal that inherits this directory,
      # so zellij opens in $HOME rather than wherever the unit started.
      WorkingDirectory = config.home.homeDirectory;
      # Everything the bar launches (sieb's drun, the scratchpad terminal)
      # inherits this unit's environment, which is systemd's, not niri's:
      # without these it has no DISPLAY for X11 apps and the plain
      # XDG_CURRENT_DESKTOP that leaves Electron on the basic keyring. Taken
      # from niri's own block so the two cannot drift.
      Environment =
        lib.mapAttrsToList (n: v: "${n}=${v}")
        (lib.filterAttrs (_: v: v != null) config.programs.niri.settings.environment);
      Restart = "on-failure";
    };
    Install.WantedBy = ["graphical-session.target"];
  };
}
