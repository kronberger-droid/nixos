# x86 notebook media box — a "focused spectre": full niri desktop without the
# development tooling or personal apps, and without common.nix (so no agenix
# secrets / kronberger system user / workstation services).
#
# The home-manager side is the lean media user (see users/media.nix), wired in
# via mkHost's userModule parameter in flake.nix.
{
  config,
  lib,
  pkgs,
  ...
}: let
  # Autologin/greeter both launch niri through niri-session (it activates
  # graphical-session.target via systemd; bare `niri` cannot). Redirect stderr
  # so the TTY stays clean — errors land in /tmp/niri-session.log.
  niriSession = "${config.programs.niri.package}/bin/niri-session";
  sessionWrapper = pkgs.writeShellScript "niri-session-quiet" ''
    exec ${niriSession} 2>/tmp/niri-session.log
  '';
in {
  nix.settings.experimental-features = ["nix-command" "flakes"];

  imports = [
    ./hardware-configuration.nix
    # System desktop pieces, cherry-picked instead of via common.nix:
    ../../modules/system/desktop/desktop.nix # niri + xdg portals + bluetooth + graphics + gvfs/udisks2
    ../../modules/system/desktop/keyring.nix # oo7 secret service (secure Helium storage)
    ../../modules/system/desktop/keyd.nix # keyd remaps (matches main machines)
    ../../modules/system/hardware/audio.nix # pipewire
    ../../modules/system/core/helium.nix # helium overlay (x86_64)
    ../../modules/system/core/fonts.nix # font set
    ../../modules/system/core/locale.nix # Europe/Vienna + de_AT locale
  ];

  # ── Boot / hardware ───────────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Media appliance on a shelf — don't suspend on lid close, AC or battery.
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };

  nixpkgs.config = {
    allowUnfree = true;
    # bitwarden-desktop (bound to Mod+Shift+P in niri.nix) pins electron 39,
    # which nixpkgs flags as EOL. Same allowance as core/nix-settings.nix.
    permittedInsecurePackages = ["electron-39.8.10"];
  };

  networking = {
    hostName = "mediaBox";
    networkmanager.enable = true;
  };

  # polkit: mounting/niri actions; rtkit: pipewire realtime priority.
  # (common.nix's core/users.nix sets these for workstations; we're not
  # importing it, so declare them here.)
  security.polkit.enable = true;
  security.rtkit.enable = true;

  # ── User ──────────────────────────────────────────────
  users.users.media = {
    isNormalUser = true;
    description = "Media";
    extraGroups = ["wheel" "networkmanager" "audio" "video" "render"];
    shell = pkgs.nushell;
    # No agenix on this host, so use a changeable initial password instead of a
    # hashed-password secret. Change it after first boot with `passwd`.
    initialPassword = "media";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFijJelcEDGPlu9aDnjkLa4TWNXXJGeyHgw6ucANynAW"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFFXI1vd+dtthymv9vLy9QuoyGHuX5ZEkDXXSPfP6NVr"
    ];
  };

  environment.shells = [pkgs.nushell];

  # ── Login: autologin straight into niri ───────────────
  services.greetd = {
    enable = true;
    settings = {
      # Runs once at boot, no prompt: autologin as `media` into niri.
      initial_session = {
        command = "${sessionWrapper}";
        user = "media";
      };
      # Fallback greeter, reached only after an explicit logout.
      default_session = {
        command = lib.concatStringsSep " " [
          "${pkgs.tuigreet}/bin/tuigreet"
          "--time"
          "--asterisks"
          "--cmd ${sessionWrapper}"
        ];
        user = "greeter";
      };
    };
  };

  # SSH for remote management.
  services.openssh = {
    enable = true;
    ports = [22];
  };

  system.stateVersion = "25.05";
}
