{...}: {
  imports = [
    ../modules/system
  ];

  # Suppress KERN_WARNING and below from the kernel console.
  # Hosts use `console=tty1`, which otherwise lets runtime printks
  # (USB hotplug, suspend/resume, ACPI) bleed into tuigreet.
  boot.consoleLogLevel = 3;
}
