{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.claude;

  # Statusline script using word-based labels (like starship's "in/on/via" style).
  #
  # Width-safe by construction: the line is assembled segment by segment, and a
  # segment is only appended while its VISIBLE text still fits in $COLUMNS.
  # Claude Code captures the script's stdout (so `tput cols` can't see the
  # terminal) but exports COLUMNS/LINES for us since v2.1.153. Keeping the line
  # from ever wrapping matters: Claude Code's renderer counts only "\n", not
  # visual wraps, so a wrapped statusline desyncs its input-box height math and
  # smears the redraw (see github.com/anthropics/claude-code issues #22115,
  # #51828). Segments are measured by their PLAIN text but emitted COLORED, so
  # truncation only ever lands on a clean boundary, never mid-escape-sequence.
  statuslineScript = pkgs.writeShellScript "claude-statusline" ''
    input=$(cat)

    # Parse JSON fields (strip stray newlines so output is always single-line)
    model=$(printf '%s' "$input" | ${pkgs.jq}/bin/jq -r '.model.display_name // "Claude"' | tr -d '\n\r')
    cwd=$(printf '%s' "$input" | ${pkgs.jq}/bin/jq -r '.workspace.current_dir // ""')
    added=$(printf '%s' "$input" | ${pkgs.jq}/bin/jq -r '.cost.total_lines_added // 0')
    removed=$(printf '%s' "$input" | ${pkgs.jq}/bin/jq -r '.cost.total_lines_removed // 0')
    ctx_used=$(printf '%s' "$input" | ${pkgs.jq}/bin/jq -r '.context_window.used_percentage // 0')

    # Width budget. Claude Code sets COLUMNS (>= v2.1.153); fall back to 80.
    # Reserve a small margin so we never butt against the exact edge.
    cols=''${COLUMNS:-80}
    if [ "$cols" -gt 6 ] 2>/dev/null; then max=$(( cols - 2 )); else max=$cols; fi

    # Colors (ANSI)
    reset='\033[0m'
    cyan='\033[36m'
    magenta='\033[35m'
    green='\033[32m'
    red='\033[31m'
    yellow='\033[33m'
    white='\033[37m'
    dim='\033[2m'

    output=""
    vis=0
    # add_segment <plain-text> <colored-text>: append only if it still fits.
    add_segment() {
      local plain="$1" colored="$2" len=''${#1}
      if [ $(( vis + len )) -le "$max" ]; then
        output+="$colored"
        vis=$(( vis + len ))
      fi
    }

    # Model
    add_segment "$model" "''${magenta}''${model}''${reset}"

    # Directory (basename)
    if [ -n "$cwd" ]; then
      dir_name=$(basename "$cwd" | tr -d '\n\r')
      add_segment " in $dir_name" " ''${white}in''${reset} ''${cyan}''${dir_name}''${reset}"
    fi

    # Git branch
    if [ -n "$cwd" ]; then
      branch=$(${pkgs.git}/bin/git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null | tr -d '\n\r')
      if [ -n "$branch" ]; then
        add_segment " on $branch" " ''${white}on''${reset} ''${green}''${branch}''${reset}"
      fi
    fi

    # Lines changed (only if non-zero)
    if [ "$added" != "0" ] || [ "$removed" != "0" ]; then
      seg_plain=" |"
      seg_color=" ''${dim}│''${reset}"
      if [ "$added" != "0" ]; then
        seg_plain+=" +$added"
        seg_color+=" ''${green}+''${added}''${reset}"
      fi
      if [ "$removed" != "0" ]; then
        seg_plain+=" -$removed"
        seg_color+=" ''${red}-''${removed}''${reset}"
      fi
      add_segment "$seg_plain" "$seg_color"
    fi

    # Context window (only if >10%)
    ctx_int=''${ctx_used%.*}
    if [ "$ctx_int" -gt 10 ] 2>/dev/null; then
      if [ "$ctx_int" -gt 75 ]; then
        ctx_color=$red
      elif [ "$ctx_int" -gt 50 ]; then
        ctx_color=$yellow
      else
        ctx_color=$dim
      fi
      add_segment " | ctx $ctx_int%" " ''${dim}│''${reset} ''${ctx_color}ctx ''${ctx_int}%''${reset}"
    fi

    printf "%b" "$output"
  '';

  # Everything that leaves this machine or becomes visible to somebody else.
  # Gated with `ask` rather than `deny`, so each stays one keystroke away
  # instead of needing a config edit to get real work done.
  #
  # Declared here rather than in a project's settings.local.json because `ask`
  # outranks `allow`: an "always allow" click cannot widen past this list, and
  # those clicks accumulate silently in a gitignored file nobody reviews. This
  # repo's own local settings had grown a blanket `Bash(git:*)`, almost
  # certainly added for `git status`, which was enough to make every push
  # automatic.
  outwardFacing =
    [
      "Bash(git push:*)"
      "Bash(deploy:*)"
      "Bash(ssh:*)"
      "Bash(nix copy:*)"
      "Bash(cachix:*)"
    ]
    # `gh`, by subcommand rather than wholesale. A blanket `Bash(gh:*)` also
    # caught `gh pr view`, `gh issue list` and every `gh api` GET, which is the
    # half worth having unprompted -- looking something up on GitHub is reading,
    # not publishing. Only the verbs that write are named here.
    #
    # `gh api` resists the same treatment: the method arrives as `-X POST` after
    # the endpoint, past where a prefix rule can see it, and gating the whole
    # subcommand would take the reads down with it. A write spelled that way is
    # left to auto mode's soft_deny below, which reads the command rather than
    # its first few words.
    ++ map (sub: "Bash(gh ${sub}:*)") [
      "pr create"
      "pr merge"
      "pr close"
      "pr reopen"
      "pr edit"
      "pr comment"
      "pr review"
      "pr ready"
      "pr lock"
      "pr unlock"
      "issue create"
      "issue close"
      "issue reopen"
      "issue edit"
      "issue comment"
      "issue delete"
      "issue transfer"
      "issue lock"
      "issue unlock"
      "issue pin"
      "issue unpin"
      "repo create"
      "repo delete"
      "repo edit"
      "repo fork"
      "repo rename"
      "repo archive"
      "repo unarchive"
      "repo sync"
      "repo deploy-key"
      "release create"
      "release edit"
      "release delete"
      "release upload"
      "gist create"
      "gist edit"
      "gist delete"
      "gist rename"
      "workflow run"
      "workflow enable"
      "workflow disable"
      "run rerun"
      "run cancel"
      "run delete"
      "secret set"
      "secret delete"
      "variable set"
      "variable delete"
      "ssh-key add"
      "ssh-key delete"
      "gpg-key add"
      "gpg-key delete"
      "label create"
      "label edit"
      "label delete"
      "label clone"
      "cache delete"
      "auth login"
      "auth logout"
      "auth refresh"
      "auth token"
    ]
    # The GitHub MCP server's write half, tool by tool: it has no wildcard
    # form, and naming the whole server would drag every search_/get_/list_
    # read into the prompt with them.
    ++ map (tool: "mcp__plugin_github_github__${tool}") [
      "add_comment_to_pending_review"
      "add_issue_comment"
      "add_reply_to_pull_request_comment"
      "create_branch"
      "create_or_update_file"
      "create_pull_request"
      "create_repository"
      "delete_file"
      "delete_repository"
      "fork_repository"
      "issue_write"
      "merge_pull_request"
      "pull_request_review_write"
      "push_files"
      "sub_issue_write"
      "update_pull_request"
      "update_pull_request_branch"
    ];

  # JSON to merge into ~/.claude/settings.json (statusline + plugins)
  settingsToMerge =
    {
      permissions.ask = outwardFacing;

      # The rules above match a command's leading text, which `nu -c "git
      # push"`, a `git -C` elsewhere, or a one-line script all walk straight
      # past. Auto mode's classifier reads a command for what it does instead,
      # so the same rule is restated for it in prose and catches the spellings
      # no prefix can enumerate. Soft rather than hard, since a hard block is
      # one that asking cannot clear: the point is a prompt, not a wall.
      # `$defaults` keeps the built-in rules, which this only adds to.
      autoMode.soft_deny = [
        "$defaults"
        "Anything that leaves this machine or becomes visible to someone else: pushing commits, branches or tags; opening, updating, merging or commenting on pull requests and issues; deploying to another host; publishing a package or release; sending mail. Confirm each one on its own, however the command is written. Permission granted for one such action does not carry to the next, and a task that plainly ends in one of these still needs that step confirmed when it arrives."
      ];

      # Defaults to true, which makes Claude Code append "End git commit
      # messages with: Co-Authored-By: ..." to its own system prompt. That
      # sits above CLAUDE.md in the prompt hierarchy, so the disclosure rule
      # in claude-md.md (trailer on request only) loses to it every time and
      # the trailer shows up however plainly it was waved off. Turning the
      # injection off is what lets the rule decide.
      includeCoAuthoredBy = false;
      # Default to the fullscreen (alternate-screen) renderer instead of the
      # inline one. The inline renderer redraws via cursor-up + erase-line,
      # which saturates at the viewport top once content scrolls past it —
      # leaving ghosted, overlapping output and the cursor drifting out of the
      # input box (upstream issue #51828). Fullscreen draws to a reserved
      # screen and repaints regions directly, avoiding that path entirely.
      # Tradeoff: the conversation isn't left in terminal scrollback on exit
      # (reopen `claude`, or scroll/PageUp inside it, to see history).
      # Per the docs this is the CLAUDE_CODE_NO_FLICKER env var, not a settings
      # key; `/tui fullscreen` does the same for a single session.
      # env = {
      #   CLAUDE_CODE_NO_FLICKER = "1";
      # };
    }
    // lib.optionalAttrs cfg.statusline.enable {
      statusLine = {
        type = "command";
        command = "${statuslineScript}";
      };
    }
    // lib.optionalAttrs (cfg.plugins != []) {
      enabledPlugins = lib.listToAttrs (map (name: {
          inherit name;
          value = true;
        })
        cfg.plugins);
    }
    // lib.optionalAttrs cfg.disableAutoMemory {
      autoMemoryEnabled = false;
    };
  settingsJson = builtins.toJSON settingsToMerge;

  # JSON to merge into ~/.claude.json (MCP servers -- user scope)
  mcpToMerge = {
    mcpServers = lib.mapAttrs (_: server:
      {
        type = "stdio";
        command = server.command;
      }
      // lib.optionalAttrs (server.args != []) {args = server.args;}
      // lib.optionalAttrs (server.env != {}) {env = server.env;})
    cfg.mcpServers;
  };
  mcpJson = builtins.toJSON mcpToMerge;

  hasAnyConfig = cfg.statusline.enable || cfg.mcpServers != {} || cfg.plugins != [] || cfg.claudeMd != "" || cfg.disableAutoMemory || cfg.skills != {} || cfg.skillDirs != {};
in {
  options.claude = {
    statusline.enable = lib.mkEnableOption "Claude Code statusline";

    disableAutoMemory = lib.mkEnableOption "disable Claude Code auto-memory";

    plugins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Claude Code plugins to enable (e.g. \"context7@claude-plugins-official\").";
    };

    claudeMd = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Content for the global ~/.claude/CLAUDE.md instructions file.";
    };

    skills = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          content = lib.mkOption {
            type = lib.types.lines;
            description = "Full SKILL.md content (frontmatter + body).";
          };
        };
      });
      default = {};
      description = "Claude Code skills written to ~/.claude/skills/<name>/SKILL.md.";
    };

    skillDirs = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = {};
      description = ''
        Directory-based Claude Code skills. Each entry symlinks a whole skill
        folder (SKILL.md plus any companion files/scripts) to
        ~/.claude/skills/<name>. Use for skills sourced from a flake input,
        as opposed to the inline `skills` option for single-file SKILL.md text.
      '';
    };

    mcpServers = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          command = lib.mkOption {
            type = lib.types.str;
            description = "Command to run the MCP server.";
          };
          args = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Arguments to pass to the command.";
          };
          env = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = {};
            description = "Environment variables for the MCP server.";
          };
        };
      });
      default = {};
      description = "MCP servers to configure in Claude Code settings.json.";
    };
  };

  config = lib.mkIf hasAnyConfig {
    home.file = lib.mkMerge [
      # Global CLAUDE.md instructions
      (lib.mkIf (cfg.claudeMd != "") {
        ".claude/CLAUDE.md".text = cfg.claudeMd;
      })

      # Skills (inline single-file SKILL.md)
      (lib.mapAttrs' (
          name: skill:
            lib.nameValuePair ".claude/skills/${name}/SKILL.md" {
              text = skill.content;
            }
        )
        cfg.skills)

      # Skills (directory-based; whole folder symlinked from a source path)
      (lib.mapAttrs' (
          name: dir:
            lib.nameValuePair ".claude/skills/${name}" {
              source = dir;
            }
        )
        cfg.skillDirs)

      # Install the statusline script (only when statusline is enabled)
      (lib.mkIf cfg.statusline.enable {
        ".config/claude/statusline.sh" = {
          source = statuslineScript;
          executable = true;
        };
      })
    ];

    # Activation script to merge settings (statusline + plugins) into ~/.claude/settings.json
    #
    # Unconditional now. The guard used to name each option that contributed a
    # key, which meant a host with the statusline off and no plugins silently
    # got none of the permission or attribution settings either. Those go in
    # for every host, so there is nothing left to guard on.
    home.activation.claudeSettings = lib.hm.dag.entryAfter ["writeBoundary"] ''
      SETTINGS_FILE="$HOME/.claude/settings.json"
      mkdir -p "$HOME/.claude"

      MERGE_JSON='${settingsJson}'

      if [ -f "$SETTINGS_FILE" ]; then
        ${pkgs.jq}/bin/jq --argjson merge "$MERGE_JSON" '. * $merge' \
          "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
      else
        echo "$MERGE_JSON" | ${pkgs.jq}/bin/jq . > "$SETTINGS_FILE"
      fi
    '';

    # Activation script to merge MCP servers into ~/.claude.json (user scope)
    home.activation.claudeMcpServers = lib.mkIf (cfg.mcpServers != {}) (lib.hm.dag.entryAfter ["writeBoundary"] ''
      CLAUDE_JSON="$HOME/.claude.json"

      MERGE_JSON='${mcpJson}'

      if [ -f "$CLAUDE_JSON" ]; then
        ${pkgs.jq}/bin/jq --argjson merge "$MERGE_JSON" '. * $merge' \
          "$CLAUDE_JSON" > "$CLAUDE_JSON.tmp" && mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON"
      else
        echo "$MERGE_JSON" | ${pkgs.jq}/bin/jq . > "$CLAUDE_JSON"
      fi
    '');
  };
}
