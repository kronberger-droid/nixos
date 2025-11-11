{ pkgs, config, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../common.nix
    ../../modules/system/tuwien-vpn.nix
    inputs.pia.nixosModules."x86_64-linux".default
  ];

  services.pia = {
    enable = true;
    authUserPassFile = config.age.secrets.pia-credentials.path;
  };

  services.tuwien-vpn = {
    enable = true;
    passwordFile = config.age.secrets.tuwien-vpn-password.path;
  };

  # Workaround for PIA OpenVPN CRL certificate issue
  # See: https://github.com/Fuwn/pia.nix/issues/2
  # See: https://github.com/openssl/openssl/discussions/24301
  # Remove crl-verify from OpenVPN configs due to malformed CRL dates
  systemd.services.fix-pia-crl = {
    description = "Remove CRL verification from PIA OpenVPN configs";
    wantedBy = [ "multi-user.target" ];
    before = [ "openvpn@.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # Remove crl-verify lines from all OpenVPN configs in /etc/openvpn/
      if [ -d /etc/openvpn ]; then
        for conf in /etc/openvpn/*.conf; do
          if [ -f "$conf" ]; then
            ${pkgs.gnused}/bin/sed -i '/crl-verify/d' "$conf"
          fi
        done
        echo "Patched PIA OpenVPN configs to remove CRL verification"
      fi
    '';
  };

  # Add sudo rules for PIA VPN control (for terminal use)
  security.sudo-rs.extraRules = [
    {
      users = [ "kronberger" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/pia";
          options = [ "NOPASSWD" "SETENV" ];
        }
      ];
    }
  ];

  # Add polkit rule for PIA VPN control (for GUI/systemd services)
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.policykit.exec" &&
            action.lookup("program") == "/run/current-system/sw/bin/pia" &&
            subject.user == "kronberger") {
            return polkit.Result.YES;
        }
    });
  '';

  environment.systemPackages = with pkgs; [
    droidcam
    android-tools
  ];

  environment.sessionVariables = {
    "__GL_SYNC_TO_VBLANK" = "1";
    "INTEL_DEBUG" = "sync";
  };

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    gamescopeSession.enable = true;
  };

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernelPackages = pkgs.linuxPackages_latest;
    kernelModules = [ "v4l2loopback" ];
    extraModulePackages = [ pkgs.linuxPackages_latest.v4l2loopback ];
    kernelParams = [
      "i915.enable_psr=0"
    ];
    extraModprobeConfig = ''
      options v4l2loopback devices=1 video_nr=42 card_label="DroidCam" exclusive_caps=1
    '';
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;

    extraPackages = with pkgs; [
      intel-media-driver
      intel-vaapi-driver
      libva-vdpau-driver
      libvdpau-va-gl
    ];

    extraPackages32 = with pkgs.pkgsi686Linux; [
      intel-media-driver
      intel-vaapi-driver
    ];
  };

  system.stateVersion = "24.11";
}
