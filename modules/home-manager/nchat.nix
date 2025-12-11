{pkgs, ...}: {
  home.packages = with pkgs; [
    nchat
  ];

  xdg = {
    desktopEntries = {
      nchat = {
        name = "nchat";
        genericName = "Terminal-based Chat Client";
        comment = "nchat - terminal-based multi-protocol chat client";
        exec = "kitty nchat";
        terminal = false;
        categories = ["Network" "InstantMessaging"];
        icon = "utilities-terminal";
      };
    };

    configFile = {
      # nchat application configuration
      "nchat/app.conf".text = ''
        # Cache settings
        cache_enabled=1

        # Download directory
        downloads_dir=${"\${HOME}"}/Downloads

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

      # nchat UI configuration
      "nchat/ui.conf".text = ''
        # Desktop notifications
        desktop_notifications=1

        # External commands
        attachment_open_command=xdg-open %1
        link_open_command=xdg-open %1

        # Clipboard integration
        clipboard_copy_command=${pkgs.wl-clipboard}/bin/wl-copy
        clipboard_paste_command=${pkgs.wl-clipboard}/bin/wl-paste

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

      # nchat color configuration - matching kitty theme
      "nchat/color.conf".text = ''
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

      # User color configuration for group chats
      "nchat/usercolor.conf".text = ''
        # Colors used for different users in group chats
        # Based on kitty's color palette
        0x6c99ba
        0x7e8d50
        0xe5b566
        0x9e4e85
        0x7dd5cf
        0xac4142
      '';
    };
  };
}
