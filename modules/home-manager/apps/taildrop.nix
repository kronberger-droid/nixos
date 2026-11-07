{config, ...}: {
  # Taildrop files wait in tailscaled's spool until something fetches them.
  # `--loop` keeps fetching as they arrive. Sending is the `send` command in
  # nushell.nix. tailscaled may not be up yet at login, thus the restarts
  # never give up.
  systemd.user.services.taildrop-receive = {
    Unit = {
      Description = "Receive Taildrop files into ~/Downloads";
      After = ["network-online.target"];
      StartLimitIntervalSec = 0;
    };

    Service = {
      ExecStart = "/run/current-system/sw/bin/tailscale file get --loop --conflict=rename ${config.home.homeDirectory}/Downloads";
      Restart = "always";
      RestartSec = 10;
    };

    Install.WantedBy = ["default.target"];
  };
}
