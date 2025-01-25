{ lib, pkgs, inputs, ... }:
{
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "backup";
  home-manager = {
    users.devPi = {
      home.username = "devPi";
      home.homeDirectory = "/home/devPi";
      programs.home-manager.enable = true;
      home.packages = with pkgs; [
        yazi
        btop
        neofetch
        fzf
        keyd
        bat
        zoxide
      ];
    
      programs.nushell = {
        enable = true;

        extraEnv = ''
          zoxide init nushell | save -f ~/.zoxide.nu
        '';

        extraConfig = ''
          source ~/.zoxide.nu
          # Disable banner
          $env.config.show_banner = false
        '';

        # Add shell aliases
        shellAliases = {
          cd = "z";
          cat = "bat";
        };
      };
  
      programs.starship = {
        enable = true;
        enableNushellIntegration = true;

        # Add custom starship settings
        settings = (with builtins; fromTOML (readFile "${pkgs.starship}/share/starship/presets/nerd-font-symbols.toml")) // {
          command_timeout = 2000;  # Global timeout (2 seconds for all commands)
          git_branch.symbol = " ";
          time = {
            disabled = false;
            format = "[$time]($style) ";
          };
        };
      };

      programs.git = {
        enable = true;
        userName = "Martin Kronberger";
        userEmail = "e12202316@student.tuwien.ac.at";

        lfs.enable = true;
        extraConfig = {
          filter.lfs = {
            required = true;
            clean = "git-lfs clean -- %f";
            smudge = "git-lfs smudge -- %f";
            process = "git-lfs filter-process";
          };
          core.editor = "hx";
        };
      };

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
                display-messages = true;
                display-inlay-hints = true;
              };
            };
            keys.normal = {
              space.space = "file_picker";
              ret.ret = ":w";
              ret.q = ":q";
              ret.w = ":wq";
            };
          };
        };
      home.stateVersion = "25.05";
    };
  };
}
