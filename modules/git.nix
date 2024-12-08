{
  programs.ssh = {
    enable = true;
    extraConfig = ''
      Host *
        AddKeysToAgent yes
        IdentityFile ~/.ssh/id_ed25519
    '';
  };

  services.ssh-agent.enable = true;
  
  programs.git = {
    enable = true;
    userName = "Martin Kronberger";
    userEmail = "e12202316@student.tuwien.ac.at";
  };
}
