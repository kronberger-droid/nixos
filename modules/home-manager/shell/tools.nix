{
  config,
  pkgs,
  ...
}: let
  c = name: "#${config.scheme.${name}}";
in {
  programs = {
    direnv = {
      enable = true;
      enableNushellIntegration = true;
      nix-direnv.enable = true;
    };
    zoxide = {
      enable = true;
      enableNushellIntegration = true;
    };
    # Rust in place of btop, styled after it as far as btm goes: rounded
    # boxes, btop's layout, the scheme's colours. Not reachable: btop's
    # height gradients and fill meters, since btm draws one colour per
    # series and has no meter widget.
    bottom = {
      enable = true;
      settings = {
        # btop's graphs carry no time axis.
        flags.hide_time = true;
        memory_graph.cache_memory = true;

        # btop's arrangement: CPU across the top; memory, disks and network
        # stacked on the left; processes taking the right.
        row = [
          {
            ratio = 2;
            child = [{type = "cpu";}];
          }
          {
            ratio = 3;
            child = [
              {
                ratio = 2;
                child = [{type = "mem";} {type = "disk";} {type = "net";}];
              }
              {
                ratio = 3;
                type = "proc";
              }
            ];
          }
        ];

        # No bg_colour, so the terminal's own background shows through.
        styles = {
          cpu = {
            all_entry_colour = c "base0B";
            avg_entry_colour = c "base08";
            cpu_core_colours = map c ["base0B" "base0C" "base0D" "base0E" "base0A" "base09"];
          };
          memory = {
            ram_colour = c "base0E";
            cache_colour = c "base0D";
            swap_colour = c "base0A";
            arc_colour = c "base0C";
          };
          # btop's download in blues, upload in reds.
          network = {
            rx_colour = c "base0D";
            tx_colour = c "base08";
            rx_total_colour = c "base0C";
            tx_total_colour = c "base09";
          };
          tables.headers = {
            colour = c "base0D";
            bold = true;
          };
          graphs = {
            graph_colour = c "base03";
            legend_text.colour = c "base04";
          };
          widgets = {
            widget_border_type = "rounded";
            border_colour = c "base03";
            selected_border_colour = c "base0D";
            widget_title = {
              colour = c "base05";
              bold = true;
            };
            text.colour = c "base05";
            selected_text = {
              colour = c "base00";
              bg_colour = c "base0D";
            };
            disabled_text.colour = c "base03";
          };
        };
      };
    };
  };

  home.packages = with pkgs; [
    flake-versions # `flake-versions tui`: pins, uncached builds, stale inputs
    bat
    # batman/batgrep/batdiff resolve `bat` from PATH rather than a baked store
    # path, so they have to sit in the same layer as bat itself.
    bat-extras.core
    translate-shell
    lynx
    file
  ];
}
