{
  pkgs,
  config,
  lib,
  ...
}: let
  # nchat *owns* its config dir: on run/setup it rewrites app.conf, ui.conf and
  # color.conf in place and deletes files it doesn't recognise (e.g. the old
  # usercolor.conf). Managing these as read-only xdg.configFile store symlinks
  # therefore (a) loses customisation when nchat normalises them and (b) breaks
  # the next `flake switch` once nchat replaces the symlink with a real file.
  #
  # Instead we seed each file into the confdir only if it is absent, then let
  # nchat take ownership. To reset a file to these defaults, delete it and
  # re-run `flake switch`.
  seedConfigs = {
    "app.conf" = ''
      # Cache settings
      cache_enabled=1

      # Download directory
      downloads_dir=''${HOME}/Downloads

      # Proxy settings (uncomment if needed)
      # proxy_host=localhost
      # proxy_port=1080

      # Attachment settings
      # 0=none, 1=selected chat, 2=all chats
      attachment_prefetch=1

      # Timestamp format (0=dynamic, 1=ISO)
      timestamp_format=0

      # Message handling
      send_typing=1
      mark_read=1
    '';

    "ui.conf" = ''
      # Desktop notifications
      desktop_notifications=1

      # External commands
      attachment_open_command=xdg-open %1
      link_open_command=xdg-open %1

      # Clipboard integration — left empty on purpose. nchat falls back to bare
      # wl-copy/wl-paste when it detects Wayland, resolved via PATH (which has
      # wl-clipboard from desktop/session-services.nix), and to its built-in clip
      # library otherwise. Interpolating an absolute wl-clipboard store path here
      # would bake it into a file that is seeded once and never rewritten, so it
      # would keep pointing at that path until a GC removes it and the clipboard
      # silently stops working.
      # clipboard_copy_command=
      # clipboard_paste_command=

      # File picker (optional)
      # file_picker_command=yazi --chooser-file=%1

      # Message editor (optional, defaults to $EDITOR)
      # message_edit_command=hx %1

      # Status indicators
      status_online_char=●
      status_offline_char=○
      status_away_char=◐

      # UI behavior
      show_emoji=1
      terminal_bell=0
      list_show_user_status=1
    '';

    "color.conf" = ''
      # Default colors - matching kitty's background/foreground
      default_color_bg=0x202020
      default_color_fg=0xd0d0d0

      # Dialog (contact selection)
      dialog_attr=
      dialog_attr_selected=reverse
      dialog_color_bg=0x202020
      dialog_color_fg=0xd0d0d0

      # Entry (input field)
      entry_attr=
      entry_color_bg=0x202020
      entry_color_fg=0xd0d0d0

      # Help bar
      help_attr=reverse
      help_color_bg=0x151515
      help_color_fg=0xd0d0d0

      # History - received messages
      history_name_attr=bold
      history_name_attr_selected=reverse
      history_name_recv_color_bg=0x202020
      history_name_recv_color_fg=0x6c99ba
      history_name_recv_group_color_bg=0x202020
      history_name_recv_group_color_fg=usercolor

      # History - sent messages
      history_name_sent_color_bg=0x202020
      history_name_sent_color_fg=0x7e8d50

      # History - message text received
      history_text_attr=
      history_text_attr_selected=reverse
      history_text_recv_color_bg=0x202020
      history_text_recv_color_fg=0xd0d0d0
      history_text_recv_group_color_bg=0x202020
      history_text_recv_group_color_fg=0xd0d0d0

      # History - message text sent
      history_text_sent_color_bg=0x202020
      history_text_sent_color_fg=0xd0d0d0

      # History - attachments and special elements
      history_text_attachment_color_bg=0x202020
      history_text_attachment_color_fg=0x7dd5cf
      history_text_quoted_color_bg=0x202020
      history_text_quoted_color_fg=0x505050
      history_text_reaction_color_bg=0x202020
      history_text_reaction_color_fg=0xe5b566

      # Chat list
      list_attr=
      list_attr_selected=reverse
      list_color_bg=0x202020
      list_color_fg=0xd0d0d0
      list_color_unread_bg=0x202020
      list_color_unread_fg=0xac4142

      # Chat list border
      listborder_attr=
      listborder_color_bg=0x202020
      listborder_color_fg=0x505050

      # Status bar
      status_attr=reverse
      status_color_bg=0x151515
      status_color_fg=0xd0d0d0

      # Top bar
      top_attr=reverse
      top_color_bg=0x151515
      top_color_fg=0xd0d0d0
    '';
  };

  seedFiles = lib.mapAttrs (name: text: pkgs.writeText "nchat-${name}" text) seedConfigs;

  seedScript = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: src: ''
    if [ ! -e "$confdir/${name}" ]; then
      $DRY_RUN_CMD install -m600 ${src} "$confdir/${name}"
    fi
  '')
  seedFiles);
in {
  home.packages = with pkgs; [
    nchat
  ];

  xdg.desktopEntries = {
    nchat = {
      name = "nchat";
      genericName = "Terminal-based Chat Client";
      comment = "nchat - terminal-based multi-protocol chat client";
      exec = "${config.terminal.bin} ${config.terminal.execFlag} nchat";
      terminal = false;
      categories = ["Network" "InstantMessaging"];
      icon = "utilities-terminal";
    };
  };

  # Seed nchat's config once, then leave it to nchat (see comment above).
  #
  # Deliberately no `mkdir -p` here. nchat decides whether it has been set up
  # solely by whether its confdir exists (main.cpp: `if (!Exists(dir)) { … }`),
  # and only in that branch does it write the `version` marker the next startup
  # validates. Creating the dir on our side means nchat never takes that branch,
  # never writes `version`, and every later run dies with "invalid config dir
  # content, exiting. use -s to setup nchat." So let nchat create the dir, and
  # only seed into one it has already initialised.
  home.activation.nchatSeedConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
    confdir="${config.xdg.configHome}/nchat"
    if [ -d "$confdir" ]; then
      ${seedScript}
    fi
  '';
}
