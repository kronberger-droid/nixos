{pkgs, ...}: {
  home.packages = with pkgs; [
    taskwarrior-tui
  ];
  programs.taskwarrior = {
    enable = true;
    package = pkgs.taskwarrior3;
    dataLocation = "/home/kronberger/Documents/tasks";
    config = {};
  };
}
