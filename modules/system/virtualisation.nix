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
    waydroid.enable = true;
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

  programs.virt-manager.enable = true;

  # Ensure OpenGL/DRI access
  hardware.graphics = {
    enable = true;
    enable32Bit = true; # If you need 32-bit support
  };

  # Add virtualisation groups to the user
  users.users.kronberger.extraGroups = ["libvirtd" "kvm" "qemu-libvirtd" "render"];
}
