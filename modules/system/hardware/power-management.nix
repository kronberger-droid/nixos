{
  config,
  pkgs,
  isNotebook ? false,
  ...
}: let
  # A host can only be hibernated safely when it tells the kernel where to
  # find the image on the next boot. Without boot.resumeDevice a hibernate
  # would "work" and then boot fresh, losing the session, so those hosts keep
  # plain suspend.
  canHibernate = config.boot.resumeDevice != "";
in {
  # Power management configuration optimized for laptops
  powerManagement = {
    enable = true;
    # powertop auto-tune disabled — TLP already manages the same knobs
    # and conflicts with powertop. Keep powertop as a package for diagnostics.
    powertop.enable = false;

    # Resume commands to ensure services restart properly
    resumeCommands = ''
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

    # Thermal management: TLP already drives PLATFORM_PROFILE_ON_{AC,BAT}.
    # Running thermald in parallel fights TLP for the same platform-profile
    # knob, so leave it off here.
    thermald.enable = false;
  };

  # Laptop-specific systemd settings
  systemd = {
    sleep.settings.Sleep =
      if isNotebook
      then {
        SuspendState = "mem";
        # No HibernateDelaySec on purpose. Without a fixed delay,
        # suspend-then-hibernate arms an ACPI low-battery alarm (or, failing
        # that, wakes hourly via RTC to sample the discharge rate) and only
        # hibernates when the battery is about to hit 5%. Measured on P14E
        # (2026-09-06): s2idle drains ~1.1%/h, hibernate ~0.1%/h, so the old
        # 90m cutoff paid a 44s image write for every lunch break to save
        # under 2% of battery.
        # HybridSleepState/HybridSleepMode were removed in systemd 261 and
        # only produced warnings on every sleep transition.
      }
      else {};
  };

  # Laptop logind settings
  services.logind =
    if isNotebook
    then {
      settings.Login = {
        # On battery, closing the lid should not be able to drain the
        # machine to death: suspend first, hibernate when the battery gets
        # low (see sleep.settings above). On external power there is nothing
        # to protect against, so plain suspend keeps resume instant.
        HandleLidSwitch =
          if canHibernate
          then "suspend-then-hibernate"
          else "suspend";
        HandleLidSwitchDocked = "ignore";
        HandleLidSwitchExternalPower = "suspend";
        HandlePowerKey = "suspend";
        IdleAction = "suspend-then-hibernate";
        IdleActionSec = "30m";
      };
    }
    else {};

  # Additional power management tools for laptops
  environment.systemPackages = with pkgs; (
    if isNotebook
    then [
      powertop
      acpi
      tlp
      brightnessctl
    ]
    else []
  );

  # Kernel parameters for power efficiency on laptops
  boot.kernelParams =
    if isNotebook
    then [
      "intel_pstate=active"
      "i915.enable_fbc=1"
      "i915.enable_psr=1"
      "i915.disable_power_well=0"
    ]
    else [];
}
