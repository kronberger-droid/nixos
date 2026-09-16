_: {
  imports = [
    ../modules/system
  ];

  # Suppress KERN_WARNING and below from the kernel console.
  # Hosts use `console=tty1`, which otherwise lets runtime printks
  # (USB hotplug, suspend/resume, ACPI) bleed into tuigreet.
  boot.consoleLogLevel = 3;

  # Every generated hardware-configuration.nix ties CPU microcode updates to
  # this flag (`hardware.cpu.intel.updateMicrocode = mkDefault
  # enableRedistributableFirmware`). Only the laptop profile used to set it,
  # so intelNuc booted with stock BIOS microcode. Fleet-wide now; the
  # homeserver, which skips common.nix, sets it in its own file.
  hardware.enableRedistributableFirmware = true;

  # The `claude` account for sandboxed Claude Code sessions, on every
  # workstation. The homeserver imports agent-sandbox.nix for its packages
  # but leaves this off: nothing there runs the agent under a second uid.
  security.agentSandbox.enable = true;
}
