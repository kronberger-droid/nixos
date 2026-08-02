{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.desktop.secretProvider;
  system = pkgs.stdenv.hostPlatform.system;
in {
  options.desktop.secretProvider = lib.mkOption {
    type = lib.types.enum ["gnome" "oo7"];
    default = "oo7";
    description = ''
      Which secret service provider to use.
      - "gnome": gnome-keyring with gcr SSH agent
      - "oo7": oo7-daemon with oo7-ssh-agent and PAM auto-unlock
    '';
  };

  config = lib.mkMerge [
    # ── Shared ───────────────────────────────────────────────────
    {
      programs.ssh.startAgent = false;
      programs.ssh.enableAskPassword = false;
      environment.systemPackages = [pkgs.libsecret];
    }

    # ── gnome-keyring ────────────────────────────────────────────
    (lib.mkIf (cfg == "gnome") {
      services.gnome.gnome-keyring.enable = true;
      services.gnome.gcr-ssh-agent.enable = true;

      # No greetd entry, for the same reason as the oo7 branch below: its PAM
      # stack is `substack login`, so nixpkgs' per-service toggles add no
      # rules there. gnome-keyring reaches the greeter through login.
      security.pam.services = {
        swaylock.enableGnomeKeyring = true;
        login.enableGnomeKeyring = true;
        passwd.enableGnomeKeyring = true;
      };

      # Ensure oo7 is off when using gnome-keyring.
      services.oo7.daemon.enable = lib.mkForce false;
      services.oo7.sshAgent.enable = lib.mkForce false;
      services.oo7.pam.enable = lib.mkForce false;
      services.oo7.portal.enable = lib.mkForce false;
    })

    # ── oo7 ──────────────────────────────────────────────────────
    # Split ownership since nixpkgs landed its own `services.oo7`:
    #
    #   `enable`  — nixpkgs. Owns the oo7-daemon unit, its D-Bus
    #               registration, the cap_ipc_lock wrapper the shipped unit
    #               execs, pam_oo7 and the .portal file.
    #   the rest  — the self-hosted `oo7-nixos` flake input, which now only
    #               carries what nixpkgs lacks: the SSH agent, the default
    #               Login collection, the gcr unlock prompt, ambient
    #               CAP_IPC_LOCK, actually starting the portal, and the
    #               PAM socket-wait race fix.
    #
    # Retire the input entirely if nixpkgs ever grows an SSH agent.
    (lib.mkIf (cfg == "oo7") {
      services.gnome.gnome-keyring.enable = lib.mkForce false;
      services.gnome.gcr-ssh-agent.enable = lib.mkForce false;

      _module.args.oo7-ssh-agent =
        inputs.oo7-nixos.packages.${system}.oo7-ssh-agent;

      services.oo7 = {
        enable = true;
        daemon.enable = true;
        sshAgent.enable = true;
        pam = {
          enable = true;
          # No "greetd" here: nixpkgs' greetd module sets useDefaultRules =
          # false and replaces the whole stack with `substack login`, so
          # greetd picks up pam_oo7 (and our socket-wait rule) through the
          # login service. Naming it directly is also an eval error now,
          # since oo7-nixos orders its wait rule against greetd's own
          # rules.session.oo7, which no longer exists.
          services = ["login" "swaylock" "passwd"];
        };
        portal.enable = true;
      };
    })
  ];
}
