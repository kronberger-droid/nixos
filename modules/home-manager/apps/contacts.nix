{
  config,
  pkgs,
  ...
}: let
  # `contacts`: a skim picker over khard, because `khard edit <name>` needs you
  # to remember the name and there are 400 of them. Built the way eww.nix builds
  # its helpers — a real .nu file with @var@ placeholders, so the script stays
  # lintable (`nu -n --ide-check 30 <file>`) and replaceVars fails the build on
  # an unfilled or unused var.
  contactsScript = pkgs.runCommandLocal "contacts" {} ''
    install -Dm755 ${
      pkgs.replaceVars ./contacts/contacts.nu {
        nu = pkgs.nushell;
        khard = config.programs.khard.package;
        inherit (pkgs) skim vdirsyncer;
      }
    } $out/bin/contacts
  '';
in {
  # services.vdirsyncer only wires the systemd timer; expose the CLI too for the
  # one-time `vdirsyncer discover` and manual syncs. (khard comes via programs.khard.)
  home.packages = [pkgs.vdirsyncer contactsScript];

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
    # Without this, a card changed on both sides since the last sync errors and
    # stops the collection syncing until it is fixed by hand — which shows up as
    # contacts quietly going stale. `a` is the local storage, so an edit made
    # here beats one made on the phone. That is the right direction for how the
    # two are used: the phone is where the email addresses are missing.
    # The cost: a DAVx5 edit landing in the same window is dropped silently.
    conflict_resolution = "a wins"

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
