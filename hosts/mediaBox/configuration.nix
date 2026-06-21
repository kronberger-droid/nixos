# x86 notebook media box — a "focused spectre": full sway desktop without the
# development tooling or personal apps, and without common.nix (so no agenix
# secrets / kronberger system user / workstation services).
#
# Compositor is sway (prebuilt from cache) rather than the niri fork, which is
# built from source — see programs.niri/sway overrides below. The home-manager
# side is the lean media user (see users/media.nix), wired in via mkHost's
# userModule parameter in flake.nix.
{
  lib,
  pkgs,
  inputs,
  ...
}: let
  # Autologin/greeter both launch sway. Home-manager's sway config sets
  # systemd.enable = true, so a bare `sway` activates graphical-session.target
  # itself (there's no separate `sway-session` binary like niri's). Redirect
  # stderr so the TTY stays clean — errors land in /tmp/sway-session.log.
  sessionWrapper = pkgs.writeShellScript "sway-session-quiet" ''
    exec ${pkgs.sway}/bin/sway 2>/tmp/sway-session.log
  '';

  # Stock nushell from nixpkgs, bypassing the global helix-mode overlay so this
  # box uses the prebuilt cache binary instead of rebuilding the fork. Must
  # match the media user's home shell (users/media.nix) — both the login shell
  # below and home-manager's programs.nushell point at the same package.
  stockNushell = inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system}.nushell;
in {
  nix.settings.experimental-features = ["nix-command" "flakes"];

  imports = [
    ./hardware-configuration.nix
    # System desktop pieces, cherry-picked instead of via common.nix:
    ../../modules/system/desktop/desktop.nix # compositor + xdg portals + bluetooth + graphics + gvfs/udisks2 (niri overridden to sway below)
    ../../modules/system/desktop/keyring.nix # oo7 secret service (secure Helium storage)
    ../../modules/system/desktop/keyd.nix # keyd remaps (matches main machines)
    ../../modules/system/hardware/audio.nix # pipewire
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

  nixpkgs.config.allowUnfree = true;

  networking = {
    hostName = "mediaBox";
    networkmanager.enable = true;
  };

  # polkit: mounting/sway actions; rtkit: pipewire realtime priority.
  # (common.nix's core/users.nix sets these for workstations; we're not
  # importing it, so declare them here.)
  security.polkit.enable = true;
  security.rtkit.enable = true;

  # ── Compositor: sway, not niri ────────────────────────
  # desktop.nix enables programs.niri with the niri-unstable fork (built from
  # source). This box uses sway instead, so turn the niri module off — that
  # drops niri-unstable from the system closure (no Rust compile) — and enable
  # sway, which comes prebuilt from the binary cache. Home-manager owns the
  # actual sway config (wayland.windowManager.sway in desktop/sway.nix); the
  # system module just provides the wrapped binary, polkit, and session bits.
  programs.niri.enable = lib.mkForce false;
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };
  # The NixOS sway module sets the sway portal backend to just ["gtk"], which
  # collides with desktop.nix's ["wlr" "gtk"] (wlr is what drives screencast on
  # this box). Force the desktop.nix intent. Only mediaBox enables programs.sway,
  # so this override stays host-local.
  xdg.portal.config.sway.default = lib.mkForce ["wlr" "gtk"];

  # keyd: the shared default profile (keyd.nix) swaps leftalt<->leftmeta, tuned
  # to the main laptops' key layout. On this box that sends the physical Super
  # key through as Alt, so sway's Mod4 (Super) bindings never fire. Map both
  # modifiers to themselves so physical Super is Mod4 again; the rest of the
  # default profile (capslock overload, nav/compose layers) is untouched.
  services.keyd.keyboards.default.settings.main = {
    leftalt = lib.mkForce "leftalt";
    leftmeta = lib.mkForce "leftmeta";
  };

  # ── User ──────────────────────────────────────────────
  users.users.media = {
    isNormalUser = true;
    description = "Media";
    extraGroups = ["wheel" "networkmanager" "audio" "video" "render"];
    shell = stockNushell;
    # No agenix on this host, so use a changeable initial password instead of a
    # hashed-password secret. Change it after first boot with `passwd`.
    initialPassword = "media";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFijJelcEDGPlu9aDnjkLa4TWNXXJGeyHgw6ucANynAW"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFFXI1vd+dtthymv9vLy9QuoyGHuX5ZEkDXXSPfP6NVr"
    ];
  };

  environment.shells = [stockNushell];

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
