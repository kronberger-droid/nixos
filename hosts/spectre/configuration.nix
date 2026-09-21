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

  # Limit build parallelism to keep the system responsive
  nix.settings = {
    cores = 8; # Leave 4 threads free for desktop responsiveness
    max-jobs = 2; # Max parallel derivation builds
  };

  system.stateVersion = "26.11";
}
