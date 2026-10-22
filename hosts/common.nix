_: {
  imports = [
    ../modules/system
  ];

  # The console lives on tty1, where tuigreet runs. Suppress KERN_WARNING and
  # below there, or runtime printks (USB hotplug, suspend/resume, ACPI) bleed
  # into the greeter.
  boot.kernelParams = ["console=tty1"];
  boot.consoleLogLevel = 3;

  # Every generated hardware-configuration.nix ties CPU microcode updates to
  # this flag (`hardware.cpu.intel.updateMicrocode = mkDefault
  # enableRedistributableFirmware`). Only the laptop profile used to set it,
  # so intelNuc booted with stock BIOS microcode. Fleet-wide now; the
  # homeserver, which skips common.nix, sets it in its own file.
  hardware.enableRedistributableFirmware = true;

  # The `claude` account for sandboxed Claude Code sessions, on every
  # workstation. The homeserver, which skips this file, enables it in its own.
  security.agentSandbox.enable = true;
}
