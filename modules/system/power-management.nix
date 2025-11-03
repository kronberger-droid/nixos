{ pkgs, isNotebook ? false, ... }:
{
  # Power management configuration optimized for laptops
  powerManagement = {
    enable = true;
    cpuFreqGovernor = if isNotebook then "powersave" else "performance";
    powertop.enable = isNotebook;

    # Resume commands to ensure services restart properly
    resumeCommands = ''
      systemctl restart thermald || true
      systemctl restart NetworkManager || true
    '';
  };

  # Laptop-specific power optimizations
  services = {
    # Enable TLP for advanced power management on laptops
    # Note: TLP and auto-cpufreq conflict, so we use TLP only
    tlp = {
      enable = isNotebook;
      settings = {
        # CPU power management
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
        CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
        CPU_MIN_PERF_ON_AC = 0;
        CPU_MAX_PERF_ON_AC = 100;
        CPU_MIN_PERF_ON_BAT = 0;
        CPU_MAX_PERF_ON_BAT = 50;

        # Turbo boost
        CPU_BOOST_ON_AC = 1;
        CPU_BOOST_ON_BAT = 0;

        # HWP (Hardware P-States)
        CPU_HWP_DYN_BOOST_ON_AC = 1;
        CPU_HWP_DYN_BOOST_ON_BAT = 0;

        # Platform profiles
        PLATFORM_PROFILE_ON_AC = "performance";
        PLATFORM_PROFILE_ON_BAT = "low-power";

        # Disk settings
        DISK_IDLE_SECS_ON_AC = 0;
        DISK_IDLE_SECS_ON_BAT = 2;

        # Graphics
        RADEON_DPM_STATE_ON_AC = "performance";
        RADEON_DPM_STATE_ON_BAT = "battery";

        # WiFi power management
        WIFI_PWR_ON_AC = "off";
        WIFI_PWR_ON_BAT = "on";

        # USB autosuspend
        USB_AUTOSUSPEND = 1;
        USB_BLACKLIST_PHONE = 1;

        # Battery care
        START_CHARGE_THRESH_BAT0 = 40;
        STOP_CHARGE_THRESH_BAT0 = 80;
        START_CHARGE_THRESH_BAT1 = 40;
        STOP_CHARGE_THRESH_BAT1 = 80;

        # Audio power saving
        SOUND_POWER_SAVE_ON_AC = 0;
        SOUND_POWER_SAVE_ON_BAT = 1;

        # Runtime power management
        RUNTIME_PM_ON_AC = "on";
        RUNTIME_PM_ON_BAT = "auto";

        # PCI Express ASPM
        PCIE_ASPM_ON_AC = "default";
        PCIE_ASPM_ON_BAT = "powersupersave";
      };
    };

    # Thermal management
    thermald.enable = true;
  };

  # Laptop-specific systemd settings
  systemd = {
    sleep.extraConfig =
      if isNotebook then ''
        SuspendState=mem
        HibernateDelaySec=90m
        HybridSleepState=disk
        HybridSleepMode=suspend
      '' else "";

    # Power-efficient service settings for laptops
    services = {
      # Reduce log verbosity to save power
      systemd-journald.serviceConfig =
        if isNotebook then {
          SystemMaxUse = "100M";
          RuntimeMaxUse = "50M";
        } else { };
    };
  };

  # Laptop logind settings
  services.logind =
    if isNotebook then {
      settings.Login = {
        HandleLidSwitch = "suspend-then-hibernate";
        HandleLidSwitchDocked = "ignore";
        HandleLidSwitchExternalPower = "suspend";
        HandlePowerKey = "suspend";
        IdleAction = "suspend-then-hibernate";
        IdleActionSec = "30m";
      };
    } else { };

  # Additional power management tools for laptops
  environment.systemPackages = with pkgs;
    (if isNotebook then [
      powertop
      acpi
      tlp
      brightnessctl
      light
    ] else [ ]);

  # Kernel parameters for power efficiency on laptops
  boot.kernelParams =
    if isNotebook then [
      "intel_pstate=active"
      "i915.enable_fbc=1"
      "i915.enable_psr=1"
      "i915.disable_power_well=0"
    ] else [ ];
}
