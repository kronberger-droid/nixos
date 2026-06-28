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

  # JSON to merge into ~/.claude/settings.json (statusline + plugins)
  settingsToMerge =
    {
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
    home.activation.claudeSettings = lib.mkIf (cfg.statusline.enable || cfg.plugins != [] || cfg.disableAutoMemory) (lib.hm.dag.entryAfter ["writeBoundary"] ''
      SETTINGS_FILE="$HOME/.claude/settings.json"
      mkdir -p "$HOME/.claude"

      MERGE_JSON='${settingsJson}'

      if [ -f "$SETTINGS_FILE" ]; then
        ${pkgs.jq}/bin/jq --argjson merge "$MERGE_JSON" '. * $merge' \
          "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
      else
        echo "$MERGE_JSON" | ${pkgs.jq}/bin/jq . > "$SETTINGS_FILE"
      fi
    '');

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
