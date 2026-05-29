{pkgs, ...}: {
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
      settings = {
        git_protocol = "ssh";
      };
    };

    gh-dash = {
      enable = true;
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
        };
      };
    };

    git = {
      enable = true;
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
      };
    };
  };
}
