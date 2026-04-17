{
  pkgs,
  config,
  ...
}: let
  mkSymlink = path:
    config.lib.file.mkOutOfStoreSymlink
    "/home/kronberger/.config/nixos/${path}";
in {
  xdg.configFile."yazi/flavors/base16-transparent.yazi/flavor.toml".source =
    mkSymlink "modules/home-manager/apps/yazi/base16-transparent.toml";

  programs.yazi = {
    enable = true;
    shellWrapperName = "y";
    plugins = {
      inherit (pkgs.yaziPlugins) bookmarks;
    };
    initLua = ''
      require("bookmarks"):setup({
        persist = "vim",      -- uppercase (A-Z) bookmarks persist across sessions
        desc_format = "full", -- show full path in bookmark list
        notify = {
          enable = true,
          timeout = 2,
          message = {
            new = "Bookmark saved",
            delete = "Bookmark deleted",
            delete_all = "All bookmarks deleted",
          },
        },
      })
    '';
    keymap = {
      mgr.prepend_keymap = [
        # Bookmarks plugin — save/jump/delete
        {
          on = ["m"];
          run = "plugin bookmarks save";
          desc = "Save bookmark";
        }
        {
          on = ["'" ];
          run = "plugin bookmarks jump";
          desc = "Jump to bookmark";
        }
        {
          on = ["b" "d"];
          run = "plugin bookmarks delete";
          desc = "Delete bookmark";
        }
        {
          on = ["b" "D"];
          run = "plugin bookmarks delete_all";
          desc = "Delete all bookmarks";
        }
        # Quick "go to" shortcuts
        {
          on = ["g" "h"];
          run = "cd ~";
          desc = "Go to home";
        }
        {
          on = ["g" "d"];
          run = "cd ~/Downloads";
          desc = "Go to Downloads";
        }
        {
          on = ["g" "o"];
          run = "cd ~/Documents";
          desc = "Go to Documents";
        }
        {
          on = ["g" "n"];
          run = "cd ~/Documents/notes/general-vault";
          desc = "Go to Obsidian vault";
        }
        {
          on = ["g" "c"];
          run = "cd ~/.config";
          desc = "Go to .config";
        }
        {
          on = ["g" "x"];
          run = "cd ~/.config/nixos";
          desc = "Go to NixOS config";
        }
        {
          on = ["g" "u"];
          run = "cd /run/media/kronberger";
          desc = "Go to USB/removable media";
        }
      ];
    };
    settings = {
      flavor = "base16-transparent";
      opener = {
        "detached-pdf" = [
          {
            run = ''setsid ${pkgs.zathura}/bin/zathura "$@"'';
            orphan = true;
          }
        ];
        "detached-image" = [
          {
            run = ''setsid ${pkgs.swayimg}/bin/swayimg "$@"'';
            orphan = true;
          }
        ];
      };

      open = {
        prepend_rules = [
          # send pdfs to detached zathura
          {
            name = "*.pdf";
            use = "detached-pdf";
          }
          # send images to detaced swayimg
          {
            name = "*.png";
            use = "detached-image";
          }
          {
            name = "*.jpg";
            use = "detached-image";
          }
          {
            name = "*.jpeg";
            use = "detached-image";
          }
          {
            name = "*.gif";
            use = "detached-image";
          }
          {
            name = "*.svg";
            use = "detached-image";
          }
        ];
      };
    };
  };
}
