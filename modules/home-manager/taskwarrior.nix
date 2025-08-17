{pkgs, ...}:
{
  programs.taskwarrior = {
    enable = true;
    package = pkgs.taskwarrior3;
    dataLocation = "$XDG_DATAHOME/home/kronberger/Documents/tasks";
    config = {
    };
  }; 
}
