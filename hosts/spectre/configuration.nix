{ pkgs, config, inputs, ... }:
{
  imports =
    [
      ./hardware-configuration.nix
      ../common.nix
      ../../modules/system/firmware/vbt.nix
      ../../modules/system/tuwien-vpn.nix
      inputs.pia.nixosModules."x86_64-linux".default
    ];

  services = {
    printing = {
      enable = true;
      drivers = [ pkgs.gutenprint ];
    };

    pia = {
      enable = true;
      authUserPassFile = config.age.secrets.pia-credentials.path;
    };

    tuwien-vpn = {
      enable = true;
      passwordFile = config.age.secrets.tuwien-vpn-password.path;
    };

    logind.settings.Login = {
      HandleLidSwitch = "suspend-then-hibernate";
      HandleLidSwitchDocked = "ignore";
      HandleLidSwitchExternalPower = "suspend";
    };

    journald = {
      storage = "persistent";
      forwardToSyslog = true;
      extraConfig = ''
        Compress=yes
        SystemMaxUse=500M
        RuntimeMaxUse=100M
      '';
    };

    udev.extraRules = ''
      SUBSYSTEM=="video4linux", KERNEL=="video[0-9]*", ATTRS{name}=="Intel MIPI Camera", MODE="0660", GROUP="video"
      ACTION=="add", SUBSYSTEM=="leds", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/leds/%k/brightness"
      ACTION=="add", SUBSYSTEM=="leds", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/leds/%k/brightness"
    '';
  };

  # Workaround for PIA OpenVPN CRL certificate issue
  # See: https://github.com/Fuwn/pia.nix/issues/2
  # The PIA configs from pia.nix include a crl-verify section with malformed CRL that OpenSSL 3.x rejects
  # Solution: Create a generic wrapper that filters CRL at runtime for any region
  systemd.services = let
    # Create a wrapper script generator that works for any region
    makeOpenvpnWrapper = region: pkgs.writeShellScript "openvpn-${region}-wrapper" ''
      # Find the most recent config using glob pattern (sorted by modification time)
      WRAPPER_CONFIG=$(${pkgs.coreutils}/bin/ls -t /nix/store/*-openvpn-config-${region} 2>/dev/null | ${pkgs.coreutils}/bin/head -1)

      if [ -z "$WRAPPER_CONFIG" ] || [ ! -f "$WRAPPER_CONFIG" ]; then
        echo "ERROR: Could not find openvpn-config-${region} in /nix/store" >&2
        exit 1
      fi

      ACTUAL_CONFIG=$(${pkgs.gnugrep}/bin/grep -oP 'config \K.*' "$WRAPPER_CONFIG" 2>/dev/null | ${pkgs.coreutils}/bin/head -1)

      if [ -z "$ACTUAL_CONFIG" ] || [ ! -f "$ACTUAL_CONFIG" ]; then
        echo "ERROR: Could not find PIA ${region} config at $ACTUAL_CONFIG" >&2
        exit 1
      fi

      # Create filtered config in /tmp without CRL section
      FILTERED="/tmp/${region}-filtered.ovpn"
      ${pkgs.gnused}/bin/sed '/<crl-verify>/,/<\/crl-verify>/d' "$ACTUAL_CONFIG" > "$FILTERED"

      # Run OpenVPN with filtered config
      exec ${pkgs.openvpn}/sbin/openvpn \
        --suppress-timestamps \
        --errors-to-stderr \
        --script-security 2 \
        --config "$FILTERED" \
        --auth-nocache \
        --auth-user-pass ${config.age.secrets.pia-credentials.path}
    '';

    # List of commonly used regions (add more as needed)
    piaRegions = [
      "austria" "australia" "au-melbourne" "au-sydney" "au-perth"
      "belgium" "brazil" "canada" "ca-toronto" "ca-montreal" "ca-vancouver"
      "denmark" "finland" "france" "germany" "italy" "japan"
      "netherlands" "norway" "poland" "spain" "sweden" "switzerland"
      "uk-london" "uk-manchester" "uk-southampton"
      "us-east" "us-west" "us-chicago" "us-texas" "us-california"
    ];

    # Generate service overrides for all regions
    serviceOverrides = pkgs.lib.genAttrs
      (map (r: "openvpn-${r}") piaRegions)
      (serviceName:
        let region = pkgs.lib.removePrefix "openvpn-" serviceName;
        in {
          serviceConfig.ExecStart = pkgs.lib.mkForce "@${makeOpenvpnWrapper region} openvpn";
          wantedBy = pkgs.lib.mkForce []; # Don't auto-start on boot
        }
      );
  in serviceOverrides;

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

  hardware = {
    enableRedistributableFirmware = true;
    ipu6 = {
      enable = true;
      platform = "ipu6ep";
    };
    firmware = [ pkgs.ipu6-camera-bins ];
    keyboard.qmk.enable = true;
  };

  boot = {
    initrd.systemd.enable = true; # Faster boot with systemd in initrd
    loader = {
      systemd-boot = {
        enable = true;
        editor = false; # Disable boot menu editor for security
        configurationLimit = 20; # Limit number of stored generations
      };
      timeout = 1; # Fast boot menu timeout
      efi.canTouchEfiVariables = true;
    };
    kernel.sysctl = {
      "kernel.sysrq" = 1;
    };
    kernelParams = [
      "nvme_core.default_ps_max_latency_us=0"
      "pcie_aspm=off"
      "snd_intel_dspcfg.dsp_driver=1"
      "intel_iommu=off"
    ];
    kernelModules = [
      "hp_wmi"
      "v4l2loopback"
    ];
    extraModulePackages = [
      config.boot.kernelPackages.v4l2loopback
    ];
    blacklistedKernelModules = [
      "iTCO_wdt"
      "watchdog"
    ];
    crashDump.enable = true;
  };

  systemd.sleep.extraConfig = ''
    SuspendState=mem
    HibernateDelaySec=90m
  '';

  environment.systemPackages = with pkgs; [
    v4l-utils
    cheese
    libcamera
    libcamera-qcam
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.icamerasrc-ipu6ep
    brightnessctl
    light
    dmidecode
  ];

  system.stateVersion = "24.11"; # Did you read the comment?

}
