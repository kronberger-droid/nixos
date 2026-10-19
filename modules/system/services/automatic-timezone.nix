{config, ...}: {
  # Follow the timezone from the network. automatic-timezoned asks geoclue for
  # city-level accuracy only, which geoclue's IP source covers on its own.
  services.automatic-timezoned.enable = true;

  # Keep geoclue to that IP lookup. The WiFi and 3G sources would send nearby
  # BSSIDs and cell IDs to beaconDB, a location precise to metres that a
  # timezone never needs. The IP source still queries beaconDB, which then only
  # learns the public IP every other site sees as well.
  services.geoclue2 = {
    enableWifi = false;
    enable3G = false;
  };

  # The NixOS module writes no [ip] section, and geoclue has no built-in method
  # (the `ichnaea` default lives only in the upstream example config), so the IP
  # source disables itself. The URL is set explicitly too: `ichnaea` would
  # otherwise borrow wifi.url, which the module leaves out once WiFi is off.
  environment.etc."geoclue/conf.d/90-ip.conf".text = ''
    [ip]
    enable=true
    method=ichnaea
    url=${config.services.geoclue2.geoProviderUrl}
  '';
  # The module only restarts geoclue on changes to geoclue.conf itself.
  systemd.services.geoclue.restartTriggers = [
    config.environment.etc."geoclue/conf.d/90-ip.conf".source
  ];
}
