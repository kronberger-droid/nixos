{
  programs.firefox = {
    enable = true;
    # Pin to legacy path: nixpkgs' firefox wrapper exports MOZ_LEGACY_PROFILES=1,
    # so firefox reads ~/.mozilla/firefox regardless of HM's configPath default.
    # Picking XDG here would make HM and the wrapper disagree about where the
    # profile lives — the root cause of the 2026-04 profile-recreation incident.
    configPath = ".mozilla/firefox";
  };

  # Hide the titlebar close button — tiling WMs (niri/sway) handle window
  # lifecycle via keybindings, so the button is dead UI. Written via home.file
  # rather than programs.firefox.profiles.*.userChrome to keep HM out of the
  # profile dir; the latter would re-engage profile management (see 478a5b3).
  home.file.".mozilla/firefox/default/chrome/userChrome.css".text = ''
    .titlebar-buttonbox-container > .titlebar-buttonbox > .titlebar-close {
      display: none !important;
    }
  '';
}
