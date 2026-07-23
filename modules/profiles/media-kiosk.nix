# Shared "browser kiosk" media-appliance profile.
#
# Boot chain: greetd autologin -> tuigreet -> Sway -> browser autostart.
# Intentionally minimal: no personal workstation stack (niri, agenix, oo7,
# rust toolchain). Both the aarch64 mediaPi and the x86 mediaBox import this;
# they differ only in hardware/boot layer and which browser they pass in.
#
# The browser is a *parameter* because Helium ships x86_64-only — the Pi must
# stay on Chromium while the x86 box uses Helium. See modules/system/core/helium.nix.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.mediaKiosk;
  sshKeys = import ../shared/ssh-keys.nix;
in {
  options.mediaKiosk = {
    enable = lib.mkEnableOption "browser-kiosk media appliance (greetd autologin -> Sway -> browser)";

    user = lib.mkOption {
      type = lib.types.str;
      default = "media";
      description = "Login/autologin user the kiosk runs as.";
    };

    hostName = lib.mkOption {
      type = lib.types.str;
      description = "System hostname.";
    };

    browserPackage = lib.mkOption {
      type = lib.types.package;
      description = "Browser package installed and launched as the kiosk app.";
    };

    browserCommand = lib.mkOption {
      type = lib.types.str;
      default = lib.getExe' cfg.browserPackage cfg.browserPackage.pname;
      defaultText = lib.literalExpression "lib.getExe' cfg.browserPackage cfg.browserPackage.pname";
      description = ''
        Command Sway autostarts on login. Defaults to the browser package's
        binary (named after its pname). Override to add launch flags, e.g.
        Wayland/Ozone flags for AppImage browsers.
      '';
    };

    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      # Pulled from shared/ssh-keys.nix rather than copied, so a rotated key
      # does not leave the kiosk trusting a stale one. Deliberately a subset
      # of that file — only the two workstations, not every machine.
      default = [
        sshKeys.intelNuc
        sshKeys.spectre
      ];
      description = "SSH public keys allowed to log into the kiosk user.";
    };
  };

  config = lib.mkIf cfg.enable {
    networking = {
      hostName = cfg.hostName;
      networkmanager.enable = true;
    };

    # mDNS — so you can `ssh ${user}@${hostName}.local`
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      publish = {
        enable = true;
        addresses = true;
      };
    };

    time.timeZone = "Europe/Vienna";
    i18n.defaultLocale = "en_US.UTF-8";

    # ── User ──────────────────────────────────────────────
    users.users.${cfg.user} = {
      isNormalUser = true;
      extraGroups = ["wheel" "networkmanager" "video" "render"];
      shell = pkgs.nushell;
      openssh.authorizedKeys.keys = cfg.authorizedKeys;
    };

    environment = {
      shells = [pkgs.nushell];
      variables = {
        EDITOR = "hx";
        VISUAL = "hx";
      };
      systemPackages = with pkgs; [
        helix
        git
        wget
        foot # terminal
        bluetuith # bluetooth TUI
        networkmanagerapplet # wifi tray
        pcmanfm # lightweight GTK file manager (mounts via gvfs/udisks2)
        cfg.browserPackage
      ];
    };

    nixpkgs.config.allowUnfree = true;

    # ── Desktop: kiosk boot chain ─────────────────────────
    programs.sway = {
      enable = true;
      wrapperFeatures.gtk = true;
    };

    # Auto-login straight into the kiosk session — no prompt.
    services.greetd = {
      enable = true;
      settings = {
        # greetd runs this once at startup with no greeter: passwordless
        # autologin as the kiosk user, straight into Sway -> browser.
        initial_session = {
          command = "${pkgs.sway}/bin/sway";
          user = cfg.user;
        };
        # Fallback greeter, only reached if you explicitly log out of Sway.
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd ${pkgs.sway}/bin/sway";
          user = "greeter";
        };
      };
    };

    # ── Bluetooth ─────────────────────────────────────────
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
    };

    # ── Audio ─────────────────────────────────────────────
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };

    # ── Removable media ───────────────────────────────────
    # udisks2 is the mount backend; udiskie (in the Sway startup below) is the
    # session daemon that watches for inserts and triggers the mount. gvfs adds
    # trash/mtp/network backends the GUI file manager expects.
    services.udisks2.enable = true;
    services.gvfs.enable = true;

    # ── SSH ───────────────────────────────────────────────
    services.openssh = {
      enable = true;
      ports = [22];
    };
    programs.ssh.startAgent = true;

    fonts.packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      nerd-fonts.symbols-only
    ];

    # ── Home Manager: the actual kiosk session ────────────
    home-manager = {
      extraSpecialArgs = {inherit inputs;};
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";
      users.${cfg.user} = {
        imports = [
          ../home-manager/shell/nushell.nix
        ];

        home = {
          username = cfg.user;
          homeDirectory = "/home/${cfg.user}";
          packages = with pkgs; [
            btop
            fastfetch
            fuzzel
          ];
          stateVersion = "25.05";
        };

        wayland.windowManager.sway = {
          enable = true;
          config = {
            terminal = "${pkgs.foot}/bin/foot";
            menu = "${pkgs.fuzzel}/bin/fuzzel";
            modifier = "Mod4";
            keybindings = lib.mkOptionDefault {
              "Mod4+e" = "exec ${pkgs.pcmanfm}/bin/pcmanfm";
            };
            startup = [
              # Auto-mount removable media; click the notification to open it in
              # the file manager. Tray icon shows in the Sway bar (trayOutput).
              {command = "${pkgs.udiskie}/bin/udiskie --automount --notify --tray --file-manager ${pkgs.pcmanfm}/bin/pcmanfm";}
              {command = cfg.browserCommand;}
            ];
            bars = [
              {
                position = "top";
                statusCommand = "${pkgs.i3status}/bin/i3status";
                trayOutput = "*";
              }
            ];
          };
        };

        programs.home-manager.enable = true;
      };
    };
  };
}
