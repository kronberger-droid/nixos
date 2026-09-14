# The zellij config both the desktop (terminals/zellij.nix, raw config.kdl
# with the full keybind map) and the homeserver (terminals/zellij-server.nix,
# programs.zellij with typed settings) share: look, persistence, the base16
# theme. A KDL fragment rather than a Nix attrset so the desktop can splice it
# into its hand-written file and the server can hand it to
# programs.zellij.extraConfig unchanged. The two used to carry separate copies
# of the theme block and had already drifted on scrollback_editor.
#
# The theme is inline in config.kdl on purpose: standalone theme files under
# zellij/themes/ need their own "themes { }" wrapper plus the newer
# base/background/emphasis_* schema, and zellij rejects this flat-hex form
# there with "No theme node found in file". Inline, the flat form works.
{
  scheme,
  scrollbackEditor,
}: ''
  simplified_ui true
  default_layout "compact"
  pane_frames false
  theme "base16"

  // Survive reboots, not just disconnects: zellij defaults session
  // serialization *off*, so a detached session is lost on restart unless we
  // opt in. serialize_pane_viewport also restores each pane's contents.
  // Matters most for SSH sessions, which are only ever detached.
  session_serialization true
  serialize_pane_viewport true

  // `Ctrl+o e` dumps the scrollback into helix for searching/editing.
  scrollback_editor "${scrollbackEditor}"

  // Don't pop the release-notes screen after a version bump on every attach.
  show_release_notes false
  show_startup_tips false

  themes {
      base16 {
          fg "#${scheme.base05}"
          bg "#${scheme.base00}"
          black "#${scheme.base01}"
          red "#${scheme.base08}"
          green "#${scheme.base0B}"
          yellow "#${scheme.base0A}"
          blue "#${scheme.base0D}"
          magenta "#${scheme.base0E}"
          cyan "#${scheme.base0C}"
          white "#${scheme.base06}"
          orange "#${scheme.base09}"
      }
  }
''
