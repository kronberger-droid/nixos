{ ... }:
{
  home.file = {
    # QuickEMU VM configurations
    "Emulation/windows-11-default.conf".source = ./quickemu/windows-11-default.conf;
    "Emulation/windows-11-spm.conf".source = ./quickemu/windows-11-spm.conf;
  };
}