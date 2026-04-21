{
  pkgs,
  config,
  ...
}: let
  scheme = config.scheme;

  # Generated palette theme — maps scheme colors to names used by base16_transparent
  base16PaletteTheme = pkgs.writeText "base16-nix.toml" ''
    inherits = "base16_transparent"

    [palette]
    # Generic names (used by base16_transparent's style rules)
    black = "#${scheme.base00}"
    red = "#${scheme.base08}"
    green = "#${scheme.base0B}"
    yellow = "#${scheme.base0A}"
    blue = "#${scheme.base0D}"
    magenta = "#${scheme.base0E}"
    cyan = "#${scheme.base0C}"
    white = "#${scheme.base05}"
    gray = "#${scheme.base03}"
    light-gray = "#${scheme.base04}"
    light-red = "#${scheme.base08}"
    light-green = "#${scheme.base0B}"
    light-yellow = "#${scheme.base0A}"
    light-blue = "#${scheme.base0D}"
    light-magenta = "#${scheme.base0E}"
    light-cyan = "#${scheme.base0C}"
    # Base16 names (for overlay use)
    base00 = "#${scheme.base00}"
    base01 = "#${scheme.base01}"
    base02 = "#${scheme.base02}"
    base03 = "#${scheme.base03}"
    base04 = "#${scheme.base04}"
    base05 = "#${scheme.base05}"
    base06 = "#${scheme.base06}"
    base07 = "#${scheme.base07}"
    base08 = "#${scheme.base08}"
    base09 = "#${scheme.base09}"
    base0A = "#${scheme.base0A}"
    base0B = "#${scheme.base0B}"
    base0C = "#${scheme.base0C}"
    base0D = "#${scheme.base0D}"
    base0E = "#${scheme.base0E}"
    base0F = "#${scheme.base0F}"
  '';

  nixosConfigPath = "/home/kronberger/.config/nixos";
  mkSymlink = path: config.lib.file.mkOutOfStoreSymlink "${nixosConfigPath}/${path}";
in {
  imports = [
    ./helix/dprint.nix
  ];

  home = {
    packages = with pkgs; [
      # Nix
      nil
      statix
      deadnix
      alejandra

      # Typst
      typst
      typstyle
      typst-live
      tinymist

      # Markdown
      rumdl
      markdown-oxide
      mermaid-cli

      # Spellcheck
      harper

      # PDF Viewer
      zathura

      # CSV
      prettier

      # General Compilers
      gcc

      # Rust
      bacon
      rust-script

      # Python
      ruff
      pyright

      # OpenGL
      glsl_analyzer
    ];

    file = {
      # Nix-generated palette (inherits base16_transparent + scheme colors)
      ".config/helix/themes/base16-nix.toml".source = base16PaletteTheme;
      # Hot-reloadable files — symlinked directly to the repo
      ".config/helix/themes/custom-base16.toml".source = mkSymlink "modules/home-manager/editors/helix/custom-base16.toml";
      ".config/helix/ignore".source = mkSymlink "modules/home-manager/editors/helix/ignore";
      ".config/harper/dictionary.txt".source = mkSymlink "modules/home-manager/editors/helix/harper_dict.txt";
      ".config/rumdl/rumdl.toml".source = mkSymlink "modules/home-manager/editors/helix/rumdl.toml";
    };
  };

  programs.helix = {
    enable = true;
    defaultEditor = true;
    settings = {
      theme = "custom-base16";
      editor = {
        text-width = 80;
        soft-wrap = {
          enable = true;
          wrap-at-text-width = true;
        };
        line-number = "relative";
        cursor-shape = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };
        statusline = {
          left = [
            "mode"
            "spinner"
            "version-control"
            "file-modification-indicator"
            "file-name"
          ];
        };
        file-picker = {
          hidden = false;
        };
        end-of-line-diagnostics = "hint";
        inline-diagnostics = {
          cursor-line = "warning";
        };
        lsp = {
          auto-signature-help = false;
          display-messages = false;
          display-inlay-hints = false;
        };
      };
      keys.normal = {
        space.space = "file_picker";
        ret = {
          ret = ":w";
          q = ":q";
          w = ":wq";
          r = ":reload-all";
        };
      };
    };

    languages = {
      language = [
        {
          name = "csv";
          formatter = {
            command = "${pkgs.prettier}/bin/prettier";
            args = ["--parser" "csv"];
          };
          auto-format = true;
        }
        {
          name = "markdown";
          language-servers = [
            "rumdl"
            "harper"
          ];
          formatter = {
            command = "${pkgs.rumdl}/bin/rumdl";
            args = ["fmt" "-"];
          };
          auto-format = true;
        }
        {
          name = "rust";
          language-servers = [
            "rust-analyzer"
            "harper"
          ];
        }
        {
          name = "typst";
          language-servers = [
            "tinymist"
            "harper"
          ];
          formatter = {
            command = "${pkgs.typstyle}/bin/typstyle";
          };
          auto-format = true;
        }
        {
          name = "python";
          language-servers = ["pyright"];
          formatter = {
            command = "${pkgs.ruff}/bin/ruff";
            args = ["format" "-"];
          };
          auto-format = true;
        }
        {
          name = "nix";
          language-servers = ["nil"];
          formatter = {
            command = "${pkgs.alejandra}/bin/alejandra";
            args = ["--quiet"];
          };
          auto-format = true;
        }
      ];
      language-server = {
        nil = {
          command = "${pkgs.nil}/bin/nil";
          file-types = ["nix"];
        };
        rust-analyzer = {
          command = "rust-analyzer";
          config = {
            check.command = "clippy";
          };
        };
        harper = {
          command = "${pkgs.harper}/bin/harper-ls";
          args = ["--stdio"];
          config = {
            harper-ls = {
              userDictPath = "~/.config/harper/dictionary.txt";
            };
          };
        };

        rumdl = {
          command = "${pkgs.rumdl}/bin/rumdl";
          args = ["server" "--stdio"];
        };

        pyright = {
          command = "${pkgs.pyright}/bin/pyright-langserver";
          args = ["--stdio"];
          config = {
            python.analysis = {
              typeCheckingMode = "basic";
            };
          };
        };
      };
    };
  };
}
