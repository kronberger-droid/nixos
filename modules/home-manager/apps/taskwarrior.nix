{
  pkgs,
  config,
  ...
}: {
  home.packages = with pkgs; [
    taskwarrior-tui
  ];
  programs.taskwarrior = {
    enable = true;
    package = pkgs.taskwarrior3;
    dataLocation = "${config.home.homeDirectory}/Documents/tasks";
    config = {};
  };
}
