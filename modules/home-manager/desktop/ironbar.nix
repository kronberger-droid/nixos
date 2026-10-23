{
  config,
  pkgs,
  lib,
  ...
}: let
  # MVP of an ironbar port of the eww bar, built to answer whether ironbar
  # can carry it before the rest gets ported. It runs beside eww: the unit
  # below is not wanted by the session, so `systemctl --user start ironbar`
  # is the only way it comes up.
  #
  # The status scripts are eww's, reached through eww's scriptPath. A real
  # port moves them under ironbar/ and drops their `eww update` calls, which
  # only refresh eww's own state and are harmless while eww runs.
  eww = name: "${config.xdg.configHome}/eww/scripts/${name}";

  # Same convention as eww.nix's `script`: real .nu files, store paths by
  # replaceVars placeholder. Executable here, since ironbar runs these by
  # store path where eww's get their mode from xdg.configFile.
  script = name: vars:
    pkgs.replaceVarsWith {
      src = ./ironbar + "/${name}.nu";
      replacements =
        vars
        // {
          inherit (pkgs) coreutils;
          nu = pkgs.nushell;
        };
      isExecutable = true;
    };

  bridge = script "bridge" {inherit (pkgs) ironbar;};
  drawer = script "drawer" {inherit (pkgs) ironbar;};
  vpnRow = script "vpn-row" {
    vpn = eww "vpn";
    on = "#${config.scheme.base0B}";
    off = "#${config.scheme.base03}";
  };
  wpctl = "${pkgs.wireplumber}/bin/wpctl";

  # A label fed by bridge.nu. `name` is what `ironbar style` targets for the
  # class swap, and the tooltip reads the ironvar the bridge sets beside it.
  bridged = name: every: extra:
    {
      type = "label";
      inherit name;
      class = "mod";
      label = "{{watch:${bridge} ${name} ${every} ${eww name}}}";
      tooltip = "#${name}_tip";
    }
    // extra;

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
  battery = "ls -d /sys/class/power_supply/BAT*";

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
  vpnPopupRow = name:
    dropRow "drop-row" "{{5000:${vpnRow} '${name}'}}" name "${eww "vpn"} toggle '${name}'";

  bar = {
    position = "top";
    height = 30;
    anchor_to_edges = true;

    start = [
      (button "menu" "" "${eww "menu"} launcher")
      {
        type = "workspaces";
        sort = "index";
      }
      (bridged "scratchpad" "listen" {on_click_left = "${eww "scratchpad"} toggle";})
    ];

    end = [
      (bridged "screenrec" "30" {
        show_if = "#screenrec_shown";
        on_click_left = "${eww "screenrec"} toggle";
      })

      # Toggles drawer: idle inhibit and DND behind the handle.
      (member "toggles" (bridged "idle" "30" {on_click_left = "${eww "idle"} toggle";}))
      (member "toggles" (bridged "dnd" "30" {on_click_left = "${eww "dnd"} toggle";}))
      (handle "toggles" "")

      sep

      (bridged "bluetooth" "5" {on_click_left = "${eww "tui"} bluetooth";})

      # Volume: the slider is the audio drawer's only member, revealed by
      # hovering the readout. It talks to wpctl directly rather than through
      # audio.nu's `set`, which wants the sink name and mic state handed back
      # from eww's poll.
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
            on_change = "!${wpctl} set-volume @DEFAULT_AUDIO_SINK@ \${0%.*}%";
          }
        ];
      })
      (bridged "audio" "2" ({
          on_click_left = "${eww "tui"} audio";
          on_click_right = "${eww "audio"} toggle-mute";
        }
        // hover "audio"))

      (bridged "mpris" "listen" {
        show_if = "#mpris_shown";
        on_click_left = "${eww "mpris"} toggle";
        on_click_right = "${eww "mpris"} next";
      })
      sep
      (bridged "network" "5" {on_click_left = "${eww "tui"} wifi";})

      # VPN: label from the bridge, popup in place of eww's vpn-menu window.
      {
        type = "custom";
        name = "vpn";
        class = "mod";
        tooltip = "#vpn_tip";
        bar = [
          {
            type = "button";
            label = "󰖂{{watch:${bridge} vpn 15 ${eww "vpn"}}}";
            on_click = "popup:toggle";
          }
        ];
        popup = [
          {
            type = "box";
            orientation = "v";
            class = "dropdown";
            widgets = [
              (vpnPopupRow "Tailscale")
              (vpnPopupRow "PIA VPN")
              (vpnPopupRow "TU Wien VPN")
              (dropRow "drop-row danger" "✕" "disconnect all" "${eww "vpn"} disconnect-all")
            ];
          }
        ];
      }

      sep
      {
        type = "battery";
        show_if = battery;
      }
      (sep // {show_if = battery;})
      {
        type = "sys_info";
        format = ["{cpu_percent:1}% " "{memory_percent:1.0}% " "{temp_c:1.0}°C "];
        on_click_left = "${eww "tui"} cpu";
      }

      sep

      # Tray drawer: spotify button and the tray behind the handle.
      (member "tray" (button "mod spotify-btn" "" (eww "spotify")))
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
        on_click_left = "${eww "tui"} calendar";
      }
      (button "power" "" "${eww "menu"} power")
    ];
  };

  configFile =
    {
      ironvar_defaults = lib.genAttrs (lib.concatMap (d: ["${d}_open" "${d}_hover" "${d}_pinned"]) ["toggles" "tray" "audio"]) (_: "false");
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

    .critical { color: @base08; }
    .warning { color: @base0A; }
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
  home.packages = [pkgs.ironbar];

  xdg.configFile = {
    "ironbar/config.json".text = builtins.toJSON configFile;
    "ironbar/style.css".text = style;
  };

  # Not wanted by graphical-session.target while this is an MVP; see the top.
  # Same environment as eww.service, since everything the bar launches
  # inherits it.
  systemd.user.services.ironbar = {
    Unit = {
      Description = "ironbar (MVP, beside eww)";
      PartOf = ["graphical-session.target"];
      After = ["graphical-session.target"];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Service = {
      ExecStart = "${pkgs.ironbar}/bin/ironbar";
      Environment =
        lib.mapAttrsToList (n: v: "${n}=${v}")
        (lib.filterAttrs (_: v: v != null) config.programs.niri.settings.environment);
      Restart = "on-failure";
    };
  };
}
