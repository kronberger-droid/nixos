{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    nil
    texlab
    tectonic
    ltex-ls
  ];

  programs.helix = {
    enable = true;
    defaultEditor = true;
    settings = {
      theme = "base16_default";
      editor = {
        line-number = "relative";
        soft-wrap.enable = true;
        lsp.display-messages = true;
      };
    };
    
    languages = {
      language-server.nil = {
        command = "${pkgs.nil}/bin/nil";
        file-types = [ "nix" ];
      };
      
      language-server.ltex = {
        command = "${pkgs.ltex-ls}/bin/ltex-ls";
        file-types = [ "latex" ];
      };
      
      language-server.texlab = {
        command = "${pkgs.texlab}/bin/texlab";
        file-types = [ "latex" ];
        config = {
          texlab = {
            rootDirectory = ".";
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
}
