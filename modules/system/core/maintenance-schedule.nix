# When the disk-heavy maintenance jobs run on workstations.
#
# A calendar timer whose time passes while the machine is hibernated fires
# the moment it resumes, with or without `Persistent` (that only covers the
# timer unit being stopped, e.g. over a reboot). The defaults put all three
# jobs in the small hours, which a workstation always sleeps through, so
# they ran together on resume: nix-optimise every morning, plus nix-gc and
# a 50-minute fstrim on Mondays, saturating the SSD while the first rebuild
# of the day evaluated.
#
# So schedule them for an hour the machine is reliably awake. intelNuc's
# journal has it up at 22:00 on every day it was used at all, while wake-up
# times range from 08:48 to 21:41. The homeserver imports nix-settings.nix
# on its own and keeps the night schedule.
{...}: {
  nix.gc.dates = "Sun 22:00";

  nix.optimise = {
    # After the collection, so it does not hash what is about to be deleted.
    dates = "Sun 22:15";
    # The default half-hour spread only widens the window a slot can be
    # slept through.
    randomizedDelaySec = "0";
  };

  services.fstrim.interval = "Wed 22:00";
  # util-linux ships the timer with RandomizedDelaySec=100min and
  # AccuracySec=1h, which would push a 22:00 slot past midnight and back
  # into hibernation.
  systemd.timers.fstrim.timerConfig = {
    RandomizedDelaySec = 0;
    AccuracySec = "1min";
  };

  # A slot slept through (days away) is still replayed on resume. Queue
  # those runs behind each other instead of letting them fight over the
  # disk.
  systemd.services = {
    nix-optimise.after = ["nix-gc.service"];
    fstrim.after = ["nix-gc.service" "nix-optimise.service"];
  };
}
