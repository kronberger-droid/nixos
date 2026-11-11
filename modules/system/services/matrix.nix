{
  config,
  lib,
  pkgs,
  inputs,
  username,
  ...
}: let
  # PERMANENT. Every user and room ID ends in this, and changing it later
  # means a fresh server. kron-berger.com keeps federation possible: turning
  # it on later is a `/.well-known/matrix/server` delegation through the
  # Cloudflare tunnel (website.nix), not a migration. It does not have to
  # resolve to this box for clients either; they are given the server URL
  # directly (shared/homeserver.nix, matrixUrl).
  hs = import ../../shared/homeserver.nix;
  serverName = hs.matrixServerName;

  # tuwunel's own default. Bound on every address like miniflux and radicale,
  # and opened on tailscale0 only (below), so it is reachable over the tailnet
  # and nowhere else, and does not depend on tailscaled having the address up
  # before tuwunel starts. Clients use the HTTPS front below (matrixUrl);
  # plain http://<tailnet IP>:6167 still works for those that allow it.
  port = 6167;

  # The bridge's appservice listener. tuwunel is its only client and runs on
  # this host, so loopback.
  bridgePort = 29318;

  bridgeDataDir = "/var/lib/mautrix-whatsapp";
  secret = name: config.age.secrets.${name}.path;
in {
  # Both appservice registrations come from agenix rather than from the
  # bridge's first start, so tuwunel knows them before the bridge ever runs.
  # Registering by hand after a deploy cannot work: until tuwunel accepts its
  # as_token the bridge exits (status 16), switch-to-configuration reports a
  # failed unit, and deploy-rs rolls the generation back.
  #
  # - mautrix-whatsapp-registration: the bridge's own, from
  #   `mautrix-whatsapp -g` against this config. Its namespaces follow
  #   appservice.bot.username and username_template, so changing either
  #   means regenerating it.
  # - matrix-doublepuppet-registration: mautrix's "appservice method" for
  #   double puppeting, a URL-less appservice whose as_token may act as any
  #   local user, so messages sent from the phone show up as us rather than
  #   as a WhatsApp ghost.
  # - mautrix-whatsapp-env: that same as_token as
  #   MAUTRIX_WHATSAPP_BRIDGE_LOGIN_SHARED_SECRET, which the bridge module
  #   writes into double_puppet.secrets.<domain>.
  #
  # tuwunel only reads root-owned copies, through LoadCredential below, so
  # the files need no tuwunel-readable owner (it is a DynamicUser anyway).
  age.secrets = {
    # Read by the bridge's preStart, which runs as the bridge user.
    mautrix-whatsapp-registration = {
      file = "${inputs.self}/secrets/mautrix-whatsapp-registration.age";
      mode = "0400";
      owner = "mautrix-whatsapp";
    };
    matrix-doublepuppet-registration = {
      file = "${inputs.self}/secrets/matrix-doublepuppet-registration.age";
      mode = "0400";
      owner = "root";
    };
    # Root-owned: systemd reads EnvironmentFile as root before dropping to
    # the bridge user, as with webdav-zotero.
    mautrix-whatsapp-env = {
      file = "${inputs.self}/secrets/mautrix-whatsapp-env.age";
      mode = "0400";
      owner = "root";
    };
  };

  services.matrix-tuwunel = {
    enable = true;
    settings.global = {
      server_name = serverName;
      address = ["0.0.0.0" "::"];
      port = [port];

      # Single user, no strangers: registration stays shut.
      allow_registration = false;

      # The one account, created on startup. tuwunel makes the first user it
      # creates an admin and logs a generated password (`journalctl -u
      # tuwunel`); change it after the first login. Every later start fails
      # this command because the user exists, which is what the ignore is
      # for. Nothing else runs at startup, so it hides nothing else.
      admin_execute = ["users create-user ${username}"];
      admin_execute_errors_ignore = true;

      # Off until it is wanted. The bridge needs none: WhatsApp traffic goes
      # bridge <-> WhatsApp, and Matrix traffic stays on this server.
      allow_federation = false;

      # Read at startup only; every *.yaml in it is one registration.
      appservice_dir = "/run/credentials/tuwunel.service";
    };
  };

  systemd.services.tuwunel = {
    serviceConfig.LoadCredential = [
      "whatsapp.yaml:${secret "mautrix-whatsapp-registration"}"
      "doublepuppet.yaml:${secret "matrix-doublepuppet-registration"}"
    ];
    # With userborn, agenix installs secrets from a unit, not the activation
    # script, and a switch that adds secrets stops it and starts it again
    # alongside tuwunel. switch-to-configuration submits one start job per
    # unit, in no fixed order, and `after` only orders jobs already queued:
    # with `after` alone tuwunel still started first, against the previous
    # agenix generation, and died at the CREDENTIALS step (ENOENT), so
    # deploy-rs rolled back. `wants` pulls agenix-chown (which requires
    # agenix-install-secrets) into tuwunel's own start transaction, so the
    # ordering holds whichever job goes first. Not `requires`: a later agenix
    # restart should not take the server down with it. radicale in
    # hosts/homeserver/configuration.nix has `after` only and the same race.
    wants = ["agenix-chown.service"];
    after = ["agenix-chown.service"];
  };

  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [port];

  # HTTPS for clients, at matrixUrl: tailscaled terminates TLS with the
  # node's tailnet certificate (HTTPS is enabled for the tailnet) and proxies
  # to tuwunel. Element Desktop needs it: its UI runs from a secure vector://
  # origin, so plain http to anything but localhost is blocked as mixed
  # content. tailscaled serves this on its own interface, so no firewall
  # entry. The config persists in tailscaled's state; the unit just makes it
  # declarative. Not services.tailscale.serve: that is for Tailscale Services
  # (svc: names approved in the admin console), not a node's own name.
  systemd.services.tailscale-serve-matrix = let
    ts = lib.getExe config.services.tailscale.package;
  in {
    description = "HTTPS front for tuwunel on the tailnet";
    after = ["tailscaled.service" "tuwunel.service"];
    wants = ["tailscaled.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${ts} serve --bg --https=443 http://127.0.0.1:${toString port}";
      ExecStop = "${ts} serve --https=443 off";
      # At boot tailscaled may not be logged in yet.
      Restart = "on-failure";
      RestartSec = 10;
    };
  };

  services.mautrix-whatsapp = {
    enable = true;

    # The default build links libolm, which nixpkgs marks insecure, so the
    # host would not evaluate. goolm is mautrix's pure-Go Olm.
    package = pkgs.mautrix-whatsapp.override {withGoolm = true;};

    # The module only wires itself to Synapse and Conduit.
    serviceDependencies = ["tuwunel.service"];

    environmentFile = secret "mautrix-whatsapp-env";

    settings = {
      homeserver = {
        address = "http://127.0.0.1:${toString port}";
        domain = serverName;
      };

      appservice = {
        address = "http://127.0.0.1:${toString bridgePort}";
        hostname = "127.0.0.1";
        port = bridgePort;
      };

      bridge.permissions = {
        # The module default is "*" = "relay", which would let any account
        # the server ever sees talk through the bridge. With registration
        # closed every account here is one of ours.
        "*" = lib.mkForce "block";
        ${serverName} = "admin";
      };

      # Chats archived on WhatsApp land in Low priority (pinned ones already
      # get m.favourite by default). Applied when a portal is created only:
      # with tag_only_on_create (default) tags are not kept in sync, and
      # tagging from Matrix never goes back to WhatsApp.
      network.archive_tag = "m.lowpriority";

      # Nothing outside this host drives logins over HTTP.
      provisioning.shared_secret = "disable";

      # End-to-bridge encryption stays off for now: bridge and homeserver
      # share this box, and WhatsApp's own E2EE ends at the bridge anyway.
      # Turning it on needs MSC4190 (tuwunel: `device_management` in the
      # registration, bridge: `encryption.msc4190 = true`) and a stable
      # `pickle_key` from an agenix environmentFile, since the module
      # regenerates config.yaml on every start.
      encryption.allow = false;
    };
  };

  # The module generates a registration only when the file is missing and
  # then copies its tokens into config.yaml. Putting ours in place first
  # makes it skip generation and use the tokens tuwunel already has.
  systemd.services.mautrix-whatsapp = {
    preStart = lib.mkBefore ''
      install -m 0640 ${secret "mautrix-whatsapp-registration"} ${bridgeDataDir}/whatsapp-registration.yaml
    '';
    # Reads its registration as the bridge user, so it needs agenix-chown
    # done, not only the files in place (see tuwunel above).
    wants = ["agenix-chown.service"];
    after = ["agenix-chown.service"];
  };
}
