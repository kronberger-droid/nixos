# Backups of everything on this box that exists nowhere else: the photo
# library and its database, calendars and contacts, Matrix history, the
# WhatsApp bridge's session and the Zotero attachments. One NVMe held the
# only copy of all of it.
#
# Two layers. The Postgres dump is local and always on: a file-level copy of
# a running database's directory is not a backup of it, the dump is. restic
# then ships the dump and the state directories off the box.
#
# Where to is not in this file. restic starts once three secrets exist, and
# the repository URL is one of them, so the choice of provider (an S3 or B2
# bucket, a Hetzner Storage Box, another machine over sftp) is made there:
#
#   restic-repository   one line, e.g. s3:https://host/bucket or
#                       sftp:user@host:/path
#   restic-password     one line, the repository's encryption password.
#                       Keep a copy outside this repo: without it the
#                       backup cannot be read, and these files are only
#                       readable by this host and the editor key.
#   restic-env          KEY=value lines for the backend's credentials
#                       (AWS_ACCESS_KEY_ID, B2_ACCOUNT_KEY, ...); may be
#                       empty for sftp.
#
# All three are in secrets/secrets.nix; create them with `agenix -e`. Then
# check the first run by hand: `systemctl start restic-backups-homeserver`
# and `restic-homeserver snapshots`. A backup nobody has restored from is a
# hope, so restore one file once.
{
  config,
  inputs,
  lib,
  ...
}: let
  secret = name: "${inputs.self}/secrets/${name}.age";
  names = ["restic-repository" "restic-password" "restic-env"];
  configured = lib.all (n: builtins.pathExists (secret n)) names;
  dumps = config.services.postgresqlBackup.location;
in {
  # Nightly, before restic. Immich is the only database here.
  services.postgresqlBackup = {
    enable = true;
    databases = ["immich"];
    startAt = "*-*-* 02:30:00";
    compression = "zstd";
  };

  age.secrets = lib.mkIf configured (lib.genAttrs names (n: {
    file = secret n;
    path = "/run/secrets/${n}";
    mode = "0400";
    owner = "root";
  }));

  services.restic.backups.homeserver = lib.mkIf configured {
    repositoryFile = "/run/secrets/restic-repository";
    passwordFile = "/run/secrets/restic-password";
    environmentFile = "/run/secrets/restic-env";
    initialize = true;
    paths = [
      dumps
      "/var/lib/immich"
      "/var/lib/radicale"
      "/var/lib/tuwunel"
      "/var/lib/mautrix-whatsapp"
      "/var/lib/webdav"
    ];
    # Immich rebuilds both from the originals.
    exclude = [
      "/var/lib/immich/thumbs"
      "/var/lib/immich/encoded-video"
    ];
    timerConfig = {
      OnCalendar = "*-*-* 03:30:00";
      # A night the box was off is caught up at the next boot.
      Persistent = true;
      RandomizedDelaySec = "30m";
    };
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 5"
      "--keep-monthly 12"
    ];
    # Reads a slice of the stored data back on every run, so a repository
    # going bad is noticed before it is needed.
    runCheck = true;
    checkOpts = ["--read-data-subset=2%"];
  };

  systemd.services.restic-backups-homeserver = lib.mkIf configured {
    after = ["postgresqlBackup-immich.service"];
  };
}
