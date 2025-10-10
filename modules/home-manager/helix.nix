# /etc/nixos/modules/home-manager/helix.nix
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Nix
    nil

    # Typst
    typst
    typstfmt
    typstyle
    typst-live
    tinymist

    # Markdown
    markdown-oxide

    # Spellcheck
    ltex-ls

    # PDF Viewer
    zathura

    #CSV
    prettier

    #General Compilers
    gcc
  ];

  imports = [
    ./helix/dprint.nix
  ];

  home.file.".config/helix/ignore".source = ./helix/ignore;

  programs.helix = {
    enable = true;
    defaultEditor = true;
    settings = {
      theme = "base16_transparent";
      editor = {
        soft-wrap.enable = true;
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
        ret.ret = ":w";
        ret.q = ":q";
        ret.w = ":wq";
        ret.r = ":reload-all";
      };
    };

    languages = {
      language = [
        {
          name = "latex";
          language-servers = [
            "texlab"
            "ltex"
          ];
        }
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
            "ltex"
            "markdown-oxide"
          ];
          formatter = {
            command = "${pkgs.dprint}/bin/dprint";
            args = [ "fmt" "--stdin" "md"];
          };
        }
        {
          name = "rust";
          language-servers = [
            "rust-analyzer"
          ];
        }
        {
          name = "typst";
          language-servers = [
            "tinymist"
          ];
          formatter = {
            command = "${pkgs.typstyle}/bin/typstyle";
          };
          auto-format = true;
        }
      ];
      language-server = {
        nil = {
          command = "${pkgs.nil}/bin/nil";
          file-types = [ "nix" ];
        };
        rust-analyzer = {
          command = "${pkgs.rust-analyzer-unwrapped}/bin/rust-analyzer";
          config = {
            check.command = "clippy";
          };
        };
        ltex = {
          command = "${pkgs.ltex-ls}/bin/ltex-ls";
          file-types = [ "latex" ];
          config = {
            ltex.dictionary = {
              "en-US" = [
                "isentropic" "Isentropic"
                "microfluidics" "Microfluidics"
                "Kronberger"
              ];
            }; 
          };
        };
      
        texlab = {
          command = "${pkgs.texlab}/bin/texlab";
          file-types = [ "latex" ];
          config = {
            texlab = {
              latexindent = {
                modifyLineBreaks = true;
              };
              rootDirectory = ".";
              completion.matcher = "prefix";
              build = {
                onSave = true;
                forwardSearchAfter = true;
                executable = "${pkgs.tectonic}/bin/tectonic";
                args = [
                  "-X"
                  "compile"
                  "main.tex"
                  "--synctex"
                  "--keep-logs"
                  "--outdir=."
                ];
              };
              forwardSearch = {
                executable = "${pkgs.zathura}/bin/zathura";
                args = [
                  "--synctex-forward"
                  "--log-level=error"
                  "%l:1:%f"
                  "main.pdf"
                ];
              };
              chktex = {
                onOpenAndSave = true;
                onEdit = true;
              };
            };
          };
        };
      };
    };
  };
}
