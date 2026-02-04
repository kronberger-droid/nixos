{
  pkgs,
  lib,
  config,
  ...
}: let
  # Statusline script with nerd font icons matching starship style
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
    bold='\033[1m'
    cyan='\033[36m'
    magenta='\033[35m'
    green='\033[32m'
    red='\033[31m'
    yellow='\033[33m'
    dim='\033[2m'

    # Nerd font icons (matching your starship config)
    model_icon="󱙺"  # AI/robot icon
    branch_icon=""  # git branch (from your starship)
    folder_icon=""  # folder
    ctx_icon="󰍛"   # memory (from your starship)

    # Build output
    output=""

    # Model with icon
    output+="''${magenta}''${model_icon} ''${model}''${reset}"

    # Directory (basename)
    if [ -n "$cwd" ]; then
      dir_name=$(basename "$cwd")
      output+=" ''${dim}│''${reset} ''${cyan}''${folder_icon} ''${dir_name}''${reset}"
    fi

    # Git branch
    if [ -n "$cwd" ]; then
      branch=$(${pkgs.git}/bin/git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
      if [ -n "$branch" ]; then
        output+=" ''${dim}│''${reset} ''${green}''${branch_icon} ''${branch}''${reset}"
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
      output+=" ''${dim}│''${reset} ''${ctx_color}''${ctx_icon} ''${ctx_int}%''${reset}"
    fi

    printf "%b" "$output"
  '';
in {
  options.claude = {
    statusline.enable = lib.mkEnableOption "Claude Code statusline";
  };

  config = lib.mkIf config.claude.statusline.enable {
    # Install the statusline script
    home.file.".config/claude/statusline.sh" = {
      source = statuslineScript;
      executable = true;
    };

    # Activation script to update settings.json without overwriting permissions
    home.activation.claudeStatusline = lib.hm.dag.entryAfter ["writeBoundary"] ''
      SETTINGS_FILE="$HOME/.claude/settings.json"
      mkdir -p "$HOME/.claude"

      if [ -f "$SETTINGS_FILE" ]; then
        # Merge statusLine into existing settings
        ${pkgs.jq}/bin/jq --arg cmd "${statuslineScript}" \
          '.statusLine = {"type": "command", "command": $cmd}' \
          "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
      else
        # Create new settings file
        echo '{"statusLine": {"type": "command", "command": "${statuslineScript}"}}' | \
          ${pkgs.jq}/bin/jq . > "$SETTINGS_FILE"
      fi
    '';
  };
}
