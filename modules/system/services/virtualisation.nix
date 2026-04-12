{pkgs, ...}: {
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

  systemd.services.virt-secret-init-encryption.enable = false;
  systemd.services.libvirt-guests.enable = false;

  programs.virt-manager.enable = true;

  # Add virtualisation groups to the user (graphics configured in desktop.nix)
  users.users.kronberger.extraGroups = ["libvirtd" "kvm" "qemu-libvirtd" "render"];
}
