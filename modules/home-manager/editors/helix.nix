{pkgs, ...}: {
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
      ".config/helix/ignore".source = ./helix/ignore;
      ".config/harper/dictionary.txt".source = ./helix/harper_dict.txt;
      ".config/rumdl/rumdl.toml".source = ./helix/rumdl.toml;
      ".config/helix/themes/custom-base16.toml".source = ./helix/custom-base16.toml;
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
          command = "${pkgs.rust-analyzer-unwrapped}/bin/rust-analyzer";
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
