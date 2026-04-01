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
      environment.systemPackages = [pkgs.libsecret];
    }

    # ── gnome-keyring ────────────────────────────────────────────
    (lib.mkIf (cfg == "gnome") {
      services.gnome.gnome-keyring.enable = true;
      services.gnome.gcr-ssh-agent.enable = true;

      security.pam.services = {
        swaylock.enableGnomeKeyring = true;
        greetd.enableGnomeKeyring = true;
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
    (lib.mkIf (cfg == "oo7") {
      services.gnome.gnome-keyring.enable = lib.mkForce false;
      services.gnome.gcr-ssh-agent.enable = lib.mkForce false;

      _module.args.oo7-ssh-agent =
        inputs.oo7-nixos.packages.${system}.oo7-ssh-agent;
      _module.args.oo7-pam =
        inputs.oo7-nixos.packages.${system}.oo7-pam;

      services.oo7 = {
        daemon.enable = true;
        sshAgent.enable = true;
        pam = {
          enable = true;
          services = ["login" "greetd" "swaylock" "passwd"];
        };
        portal.enable = true;
      };
    })
  ];
}
