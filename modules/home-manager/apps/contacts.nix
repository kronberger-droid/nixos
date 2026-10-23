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
        inherit (pkgs) coreutils;
        khard = config.programs.khard.package;
        inherit (pkgs) skim;
        pimsync = config.programs.pimsync.package;
      }
    } $out/bin/contacts
  '';
in {
  home.packages = [contactsScript];

  # Contacts pipeline: Radicale (homeserver, over tailnet) <-> pimsync <->
  # local vCard dir <-> khard.
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

  # Written by hand rather than through the account's `pimsync.enable`: that
  # generator points the local storage at the account dir
  # (~/.local/share/contacts/homeserver), but a vdir storage is a directory
  # *of* collections, so the address book khard reads would turn into the
  # storage root. Pointing at basePath with `homeserver` as the collection
  # keeps the on-disk layout vdirsyncer left behind.
  programs.pimsync = {
    enable = true;
    settings = let
      d = name: params: {inherit name params;};
    in [
      (d "status_path" ["${config.xdg.dataHome}/pimsync/status"])
      {
        name = "pair";
        params = ["homeserver"];
        children = [
          (d "storage_a" ["homeserver_local"])
          (d "storage_b" ["homeserver_remote"])
          (d "collection" ["homeserver"])
          # Without this, a card changed on both sides since the last sync is
          # left in conflict, which shows up as contacts quietly going stale.
          # `a` is the local storage, so an edit made here beats one made on
          # the phone. That is the right direction for how the two are used:
          # the phone is where the email addresses are missing. The cost: a
          # DAVx5 edit landing in the same window is dropped silently.
          (d "conflict_resolution" ["keep" "a"])
        ];
      }
      {
        name = "storage";
        params = ["homeserver_local"];
        children = [
          (d "type" ["vdir/vcard"])
          (d "path" ["${config.accounts.contact.basePath}/"])
          (d "fileext" ["vcf"])
        ];
      }
      {
        name = "storage";
        params = ["homeserver_remote"];
        children = [
          (d "type" ["carddav"])
          (d "url" ["http://homeserver:5232/"])
          (d "username" ["kronberger"])
          {
            name = "password";
            children = [(d "cmd" ["${pkgs.coreutils}/bin/cat" "/run/secrets/radicale-password"])];
          }
        ];
      }
    ];
  };

  # A timer running one-shot syncs, not services.pimsync's long-running
  # `daemon`: the picker in contacts.nu syncs on its own before every edit
  # session, and a daemon would have that run against the status database
  # it holds open. Every 5 minutes, as vdirsyncer.timer did.
  systemd.user.services.pimsync = {
    Unit.Description = "Sync contacts with Radicale";
    Service = {
      Type = "oneshot";
      ExecStart = "${config.programs.pimsync.package}/bin/pimsync sync";
    };
  };
  systemd.user.timers.pimsync = {
    Unit.Description = "Periodic pimsync";
    Timer = {
      OnCalendar = "*:0/5";
      Persistent = true;
    };
    Install.WantedBy = ["timers.target"];
  };

  # pimsync creates the `homeserver` collection on first sync but not the
  # storage root it lives in. On a host where vdirsyncer was never
  # `discover`ed (intelNuc), nothing else creates it.
  systemd.user.tmpfiles.rules = ["d ${config.accounts.contact.basePath} 0700 - - -"];
}
