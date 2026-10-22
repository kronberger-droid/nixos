_: {
  imports = [
    ./hardware-configuration.nix
    ../common.nix
    ../../modules/profiles/secureboot-laptop.nix
    ../../modules/system/hardware/firmware/vbt.nix
    ../../modules/system/hardware/ipu6-camera.nix
    ../../modules/system/hardware/scx-schedulers.nix
    ../../modules/profiles/vpn-workstation.nix
    ../../modules/system/hardware/droidcam.nix
  ];

  # HP Spectre specifics on top of the shared laptop profile. No resume
  # device here: the swapfile exists but hibernation was never wired up on
  # this host, so power-management.nix's canHibernate stays false and lid /
  # idle actions fall back to plain suspend.
  services.udev.extraRules = ''
    # Prevent Realtek SD card reader from runtime suspending
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10ec", ATTR{device}=="0x525a", ATTR{power/control}="on"
  '';

  boot.kernelModules = [
    "hp_wmi"
  ];

  # This machine's NVMe crashed with APST and ASPM on (2f12b06). Spectre
  # only: P14E never had the problem, and on it these would keep the SoC out
  # of its deep idle states and make TLP's PCIE_ASPM_ON_BAT a no-op.
  boot.kernelParams = [
    "nvme_core.default_ps_max_latency_us=0"
    "pcie_aspm=off"
  ];

  # Limit build parallelism to keep the system responsive
  nix.settings = {
    cores = 8; # Leave 4 threads free for desktop responsiveness
    max-jobs = 2; # Max parallel derivation builds
  };

  system.stateVersion = "26.11";
}
