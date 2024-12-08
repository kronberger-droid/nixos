{
  programs.ssh = {
    enable = true;
    startAgent = true;
    extraConfig = ''
      AddKeysToAgent yes
      UseKeychain yes
    '';
  };

  services.ssh-agent.enable = true;
  
  programs.git = {
    enable = true;
    userName = "Martin Kronberger";
    userEmail = "e12202316@student.tuwien.ac.at";
  };
}
