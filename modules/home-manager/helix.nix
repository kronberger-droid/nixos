{ pkgs, ... }:

{
  home.packages = with pkgs; [
    nil
    texlab
    tectonic
    ltex-ls
    texlivePackages.latexindent
    zathura
    markdown-oxide
  ];

  programs.helix = {
    enable = true;
    defaultEditor = true;
    settings = {
      theme = "base16_default";
      editor = {
        end-of-line-diagnostics = "hint";
        soft-wrap.enable = true;
        line-number = "relative";
        cursor-shape = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };
        statusline = {
          left = [ "mode" "spinner" "version-control" "file-name" ];
        };
        inline-diagnostics = {
          cursor-line = "error";
          other-lines = "disable";
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
          name = "rust";
          language-servers = [
            "rust-analyzer"
          ];
        }
      ];
      language-server = {
        nil = {
          command = "${pkgs.nil}/bin/nil";
          file-types = [ "nix" ];
        };
      
        rust-analyzer = {
          command = "${pkgs.rust-analyzer}/bin/rust-analyzer";
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
