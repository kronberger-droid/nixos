{ pkgs, ... }:

{
  home.packages = with pkgs; [
    nil
    texlab
    tectonic
    ltex-ls
    texlivePackages.latexindent
    zathura
  ];

  programs.helix = {
    enable = true;
    defaultEditor = true;
    settings = {
      theme = "base16_default";
      editor = {
        end-of-line-diagnostics = "hint";
        soft-wrap.enable = true;
        cursor-shape = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };
        indent-guides = {
          character = "╎";
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
          display-messages = true;
          display-inlay-hints = true;
        };
      };
    };

    languages = {
      language = [{
        name = "latex";
        language-servers = [
        "texlab"
        "ltex"
        ];
      }];
      language-server = {
        nil = {
          command = "${pkgs.nil}/bin/nil";
          file-types = [ "nix" ];
        };
      
        ltex = {
          command = "${pkgs.ltex-ls}/bin/ltex-ls";
          file-types = [ "latex" ];
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
                  "--outdir=build"
                ];
                directory = "build";
                auxDirectory = "build";
              };
              forwardSearch = {
                executable = "${pkgs.zathura}/bin/zathura";
                args = [
                  "--synctex-forward"
                  "%l:1:%f"
                  "build/main.pdf"
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
