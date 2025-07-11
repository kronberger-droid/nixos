{ config, pkgs, ... }:
{
  # Install QuickEMU
  environment.systemPackages = with pkgs; [
    quickemu
    qemu
    samba
  ];
  
  # Enable KVM for better performance
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;
  
  # Add your user to necessary groups
  users.users.kronberger = {
    extraGroups = [ "libvirtd" "kvm" "qemu-libvirtd" ];
  };
  
  # Create the shared directory with proper permissions
  systemd.tmpfiles.rules = [
    "d /home/kronberger/Shared 0755 kronberger users -"
  ];
}
