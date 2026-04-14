{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.claude;

  # Statusline script using word-based labels (like starship's "in/on/via" style)
  statuslineScript = pkgs.writeShellScript "claude-statusline" ''
    input=$(cat)

    # Parse JSON fields
    model=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.model.display_name // "Claude"')
    cwd=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.workspace.current_dir // ""')
    added=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.cost.total_lines_added // 0')
    removed=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.cost.total_lines_removed // 0')
    ctx_used=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.context_window.used_percentage // 0')

    # Colors (ANSI)
    reset='\033[0m'
    cyan='\033[36m'
    magenta='\033[35m'
    green='\033[32m'
    red='\033[31m'
    yellow='\033[33m'
    white='\033[37m'
    dim='\033[2m'

    # Build output
    output=""

    # Model
    output+="''${magenta}''${model}''${reset}"

    # Directory (basename)
    if [ -n "$cwd" ]; then
      dir_name=$(basename "$cwd")
      output+=" ''${white}in''${reset} ''${cyan}''${dir_name}''${reset}"
    fi

    # Git branch
    if [ -n "$cwd" ]; then
      branch=$(${pkgs.git}/bin/git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
      if [ -n "$branch" ]; then
        output+=" ''${white}on''${reset} ''${green}''${branch}''${reset}"
      fi
    fi

    # Lines changed (only if non-zero)
    if [ "$added" != "0" ] || [ "$removed" != "0" ]; then
      output+=" ''${dim}│''${reset}"
      if [ "$added" != "0" ]; then
        output+=" ''${green}+''${added}''${reset}"
      fi
      if [ "$removed" != "0" ]; then
        output+=" ''${red}-''${removed}''${reset}"
      fi
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
      output+=" ''${dim}│''${reset} ''${ctx_color}ctx ''${ctx_int}%''${reset}"
    fi

    printf "%b" "$output"
  '';

  # JSON to merge into ~/.claude/settings.json (statusline + plugins)
  settingsToMerge =
    lib.optionalAttrs cfg.statusline.enable {
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

  hasAnyConfig = cfg.statusline.enable || cfg.mcpServers != {} || cfg.plugins != [] || cfg.claudeMd != "" || cfg.disableAutoMemory || cfg.skills != {};
in {
  options.claude = {
    statusline.enable = lib.mkEnableOption "Claude Code statusline";

    disableAutoMemory = lib.mkEnableOption "disable Claude Code auto-memory (use Obsidian vault via notal instead)";

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
    # Global CLAUDE.md instructions
    home.file.".claude/CLAUDE.md" = lib.mkIf (cfg.claudeMd != "") {
      text = cfg.claudeMd;
    };

    # Skills
    home.file = lib.mapAttrs' (name: skill:
      lib.nameValuePair ".claude/skills/${name}/SKILL.md" {
        text = skill.content;
      }
    ) cfg.skills;

    # Install the statusline script (only when statusline is enabled)
    home.file.".config/claude/statusline.sh" = lib.mkIf cfg.statusline.enable {
      source = statuslineScript;
      executable = true;
    };

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
