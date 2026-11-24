{pkgs, ...}: {
  home.packages = [pkgs.helium];

  # Widevine, so Netflix and other DRM sites play. Helium inherits
  # ungoogled-chromium's removal of the component updater that would normally
  # download the CDM, but the loader is still compiled in. On Linux that loader
  # reads this hint file at startup to find a CDM outside the install dir, so
  # pointing it at the nixpkgs blob is enough and the Helium package itself
  # stays untouched. Linux only gets Widevine L3: Netflix caps at 720p.
  xdg.configFile."net.imput.helium/WidevineCdm/latest-component-updated-widevine-cdm".text = builtins.toJSON {
    Path = "${pkgs.widevine-cdm}/share/google/chrome/WidevineCdm";
  };
}
