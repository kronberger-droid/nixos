{
  programs.firefox = {
    enable = true;
    # Pin to legacy path: nixpkgs' firefox wrapper exports MOZ_LEGACY_PROFILES=1,
    # so firefox reads ~/.mozilla/firefox regardless of HM's configPath default.
    # Picking XDG here would make HM and the wrapper disagree about where the
    # profile lives — the root cause of the 2026-04 profile-recreation incident.
    configPath = ".mozilla/firefox";
  };
}
