{ pkgs, ... }:
{
  # Install QuickEMU
  environment.systemPackages = with pkgs; [
    quickemu
    qemu
    samba
    apptainer
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
      };
    };
  };
  programs.virt-manager.enable = true;

  # Add virtualisation groups to the user
  # Note: Main user configuration is in hosts/common.nix
  users.users.kronberger.extraGroups = [ "libvirtd" "kvm" "qemu-libvirtd" ];
}
