{
  config,
  pkgs,
  ...
}: let
  s = config.scheme;

  # `gh` resolves GH_TOKEN ahead of ~/.config/gh/hosts.yml, so `gh auth
  # login` is never needed, which matters: that flow would try to write
  # ~/.config/gh/config.yml, a read-only home-manager store symlink. The
  # token is read when the program starts and not exported from the shell,
  # where every process of the session would inherit it. A GH_TOKEN already
  # set wins, which is how the sandbox account's reaches it.
  withToken = bin: pkg:
    pkgs.symlinkJoin {
      inherit (pkg) pname version;
      paths = [pkg];
      nativeBuildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/${bin} --run '[ -n "''${GH_TOKEN-}" ] || ! [ -r /run/secrets/gh-dash-token ] || export GH_TOKEN="$(< /run/secrets/gh-dash-token)"'
      '';
      inherit (pkg) meta;
    };
in {
  programs = {
    delta = {
      enable = true;
      enableGitIntegration = true;
      options = {
        line-numbers = true;
        side-by-side = true;
        syntax-theme = "base16";
      };
    };

    gh = {
      enable = true;
      package = withToken "gh" pkgs.gh;
      settings = {
        git_protocol = "ssh";
      };
    };

    gh-dash = {
      enable = true;
      package = withToken "gh-dash" pkgs.gh-dash;
      settings = {
        prSections = [
          {
            title = "Needs my review";
            filters = "is:open review-requested:@me -author:@me archived:false";
          }
          {
            title = "Mine";
            filters = "is:open author:@me archived:false";
          }
          {
            title = "Involved";
            filters = "is:open involves:@me -author:@me -review-requested:@me archived:false";
          }
          {
            title = "Ready to merge";
            filters = "is:open author:@me review:approved status:success archived:false";
          }
        ];
        issuesSections = [
          {
            title = "Assigned to me";
            filters = "is:open assignee:@me archived:false";
          }
          {
            title = "Mine";
            filters = "is:open author:@me archived:false";
          }
          {
            title = "Involved";
            filters = "is:open involves:@me -author:@me -assignee:@me archived:false";
          }
        ];
        defaults = {
          preview = {
            open = true;
            width = 60;
          };
          prsLimit = 25;
          issuesLimit = 25;
          view = "prs";
          layout = {
            prs = {
              updatedAt = {
                width = 7;
                hidden = false;
              };
              repo = {
                width = 22;
              };
              author = {
                width = 15;
              };
              assignees = {
                width = 20;
                hidden = false;
              };
              base = {
                width = 15;
                hidden = true;
              };
              lines = {
                width = 16;
              };
            };
            issues = {
              updatedAt = {
                width = 7;
                hidden = false;
              };
              repo = {
                width = 22;
              };
              creator = {
                width = 15;
              };
              assignees = {
                width = 20;
                hidden = false;
              };
            };
          };
          refetchIntervalMinutes = 30;
          dateFormat = "2006-01-02";
        };
        keybindings = {
          prs = [
            {
              key = "c";
              command = "gh pr checkout {{.PrNumber}}";
            }
            {
              key = "C";
              command = "gh pr comment {{.PrNumber}}";
            }
          ];
          issues = [
            {
              key = "C";
              command = "gh issue comment {{.IssueNumber}}";
            }
          ];
        };
        pager = {
          diff = "delta";
        };
        confirmQuit = false;
        showAuthorIcons = true;
        theme = {
          ui = {
            sectionsShowCount = true;
            table = {
              showSeparator = true;
              compact = false;
            };
          };
          # base16 mapping. gh-dash falls back to its built-in ANSI defaults per
          # field, so anything left out here still renders sanely.
          colors = {
            text = {
              primary = "#${s.base05}";
              secondary = "#${s.base04}";
              # Drawn on top of the faint/selected backgrounds, so it has to be
              # the background colour, not a lighter foreground.
              inverted = "#${s.base00}";
              faint = "#${s.base03}";
              warning = "#${s.base0A}";
              success = "#${s.base0B}";
              error = "#${s.base08}";
              actor = "#${s.base0D}";
            };
            background.selected = "#${s.base02}";
            border = {
              primary = "#${s.base03}";
              secondary = "#${s.base04}";
              # Not only a border: gh-dash also uses this slot as the *background*
              # for the tab bar and footer, which is exactly base01's role.
              faint = "#${s.base01}";
            };
            # Author role icons, ordered least to most privileged.
            icon = {
              newcontributor = "#${s.base0C}";
              contributor = "#${s.base0D}";
              collaborator = "#${s.base0B}";
              member = "#${s.base0E}";
              owner = "#${s.base0F}";
              unknownrole = "#${s.base03}";
            };
          };
        };
      };
    };

    git = {
      enable = true;
      lfs.enable = true;
      signing.format = null;
      ignores = [
        ".rumdl_cache"
        ".claude/settings.local.json"
        ".direnv"
        ".envrc"
      ];
      settings = {
        user = {
          name = "kronberger-droid";
          email = "kronberger@proton.me";
        };
        init.defaultBranch = "main";
        pull.rebase = true;
        push.autoSetupRemote = true;
        # The Claude Code sandbox account (system/security/agent-sandbox.nix)
        # keeps its checkouts under /home/claude/Projects, and this user fetches
        # from them as a local remote. git refuses a repository owned by
        # another uid ("dubious ownership") unless safe.directory lists it,
        # and a global `/home/claude/Projects/*/*` entry would make every git
        # command run inside one of those checkouts honour the agent's
        # .git/config (core.fsmonitor, hooks, core.pager): code execution as
        # this user from a plain `git status`. So the trust is per command:
        # `git fetch-sandbox <remote-or-path> [refspec...]` names only the
        # repository being fetched, and fetching runs none of that config.
        # With no argument it fetches the `sandbox` remote, which the
        # `claude` launcher (security/claude-enter.nu) keeps pointed at the
        # sandbox's checkout of the repo.
        alias.fetch-sandbox = ''!f() { [ $# -gt 0 ] || set -- sandbox; url=$(git remote get-url "$1" 2>/dev/null || printf %s "$1"); git -c safe.directory="$url" fetch "$@"; }; f'';
      };
    };
  };
}
