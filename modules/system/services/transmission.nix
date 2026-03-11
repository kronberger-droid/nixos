{pkgs, ...}: {
  services.transmission = {
    enable = true;
    package = pkgs.transmission_4;
    openFirewall = true;
    settings = {
      download-dir = "/home/kronberger/Downloads";
      rpc-bind-address = "127.0.0.1";
    };
  };
}
