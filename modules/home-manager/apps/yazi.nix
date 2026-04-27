{
  pkgs,
  config,
  ...
}: let
  mkSymlink = path:
    config.lib.file.mkOutOfStoreSymlink
    "/home/kronberger/.config/nixos/${path}";

  # Yazi 26.1.22 hardcodes Rio → [Iip, Sixel] in `yazi-adapter::Brand::adapters`,
  # but Rio 0.3.11 doesn't actually render iTerm2 inline images (the cell-anchored
  # atlas path is unwired in its renderer), so PDF previews go stale.
  # Yazi's `main` flipped Rio → [Kgp] (commit c4c533e, 2026-04-26), which routes
  # through Rio's working virtual-placement path. Pin to that snapshot until
  # the next yazi release lands in nixpkgs. Tracking: rio#1530.
  yaziMaster = pkgs.yazi.overrideAttrs (old: rec {
    version = "26.1.22-unstable-2026-04-26";
    src = pkgs.fetchFromGitHub {
      owner = "sxyazi";
      repo = "yazi";
      rev = "c4c533e3efca8da498b137dfc907bc5e20090f93";
      hash = "sha256-/aRe0XpElRx8zLYAjhd3SroJn90hRqfCqhHJEZKUQB0=";
    };
    cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
      inherit src;
      name = "yazi-${version}-vendor";
      hash = "sha256-0wIbl7csRdifBnPMR0HfL/Rx90ehNf5O5O3UBXZXOpo=";
    };
  });
in {
  xdg.configFile."yazi/flavors/base16-transparent.yazi/flavor.toml".source =
    mkSymlink "modules/home-manager/apps/yazi/base16-transparent.toml";

  programs.yazi = {
    enable = true;
    package = yaziMaster;
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
          run = "cd ${config.vault.path}";
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
