{
  pkgs,
  username,
  ...
}: {
  # Install QuickEMU and related packages
  environment.systemPackages = with pkgs; [
    quickemu
    qemu
    samba
    apptainer
    spice
    virt-viewer
    mesa
    virglrenderer
    # Compose v2. Not the Docker daemon — just the orchestrator binary, which
    # `podman compose` execs as its provider with DOCKER_HOST already pointed
    # at the rootless podman socket.
    docker-compose
  ];

  # Enable KVM for better performance
  virtualisation = {
    libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = false;
        swtpm.enable = true;
        verbatimConfig = ''
          # Enable virgl renderer
          nographics_allow_host_audio = 1
        '';
      };
    };
  };

  # Podman instead of Docker: rootless containers with no daemon sitting
  # around. Only the workstations get this; the homeserver cherry-picks its
  # modules, never imports this one, and keeps Docker so wiesinger can deploy
  # containers without touching Nix.
  virtualisation.podman = {
    enable = true;
    # Puts a `docker` symlink to podman on PATH, so muscle memory and anything
    # that shells out to `docker` keeps working.
    dockerCompat = true;
    # Podman's default network runs no DNS, unlike Docker's user-defined
    # bridges. Without this, containers in a compose stack can't resolve each
    # other by service name.
    defaultNetwork.settings.dns_enabled = true;
    # Deliberately no `dockerSocket.enable`: that exposes the *rootful* podman
    # socket at /run/docker.sock and needs a `podman` group whose members can
    # trivially become root. Rootless is the whole point here.
    #
    # Prunes root-owned storage only. Rootless images live under
    # ~/.local/share/containers and need `podman system prune` by hand.
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  systemd.services.virt-secret-init-encryption.enable = false;
  systemd.services.libvirt-guests.enable = false;

  programs.virt-manager.enable = true;

  # Add virtualisation groups to the user (graphics configured in desktop.nix)
  users.users.${username}.extraGroups = ["libvirtd" "kvm" "qemu-libvirtd" "render"];
}
