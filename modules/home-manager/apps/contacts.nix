{
  config,
  pkgs,
  ...
}: {
  # services.vdirsyncer only wires the systemd timer; expose the CLI too for the
  # one-time `vdirsyncer discover` and manual syncs. (khard comes via programs.khard.)
  home.packages = [pkgs.vdirsyncer];

  # Contacts pipeline: Radicale (homeserver, over tailnet) <-> vdirsyncer <->
  # local vCard dir <-> khard, which aerc queries for address autocomplete.
  # The phone syncs the same Radicale via DAVx5 into its stock Contacts app.
  accounts.contact = {
    basePath = "${config.home.homeDirectory}/.local/share/contacts";
    accounts.homeserver = {
      local = {
        type = "filesystem";
        fileExt = ".vcf";
      };
      remote = {
        type = "carddav";
        url = "http://homeserver:5232/";
        userName = "kronberger";
        # Plaintext CardDAV password from agenix (see security/agenix.nix).
        passwordCommand = ["cat" "/run/secrets/radicale-password"];
      };
      khard.enable = true;
    };
  };

  programs.khard.enable = true;

  # This home-manager version has no vdirsyncer config renderer (accounts.contact
  # only generates khard.conf), so write the config by hand. The collection is
  # named `homeserver` to match the khard addressbook path generated above
  # (~/.local/share/contacts/homeserver). `vdirsyncer discover` creates the
  # collection on Radicale on first run; the timer then syncs non-interactively.
  xdg.configFile."vdirsyncer/config".text = ''
    [general]
    status_path = "~/.local/share/vdirsyncer/status/"

    [pair homeserver]
    a = "homeserver_local"
    b = "homeserver_remote"
    collections = ["homeserver"]

    [storage homeserver_local]
    type = "filesystem"
    path = "~/.local/share/contacts/"
    fileext = ".vcf"

    [storage homeserver_remote]
    type = "carddav"
    url = "http://homeserver:5232/"
    username = "kronberger"
    password.fetch = ["command", "cat", "/run/secrets/radicale-password"]
  '';

  # Periodic `vdirsyncer sync` via a systemd user timer.
  services.vdirsyncer.enable = true;
}
