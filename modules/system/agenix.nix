{ inputs, ... }:
{
  age = {
    identityPaths = [ "/home/kronberger/.ssh/id_ed25519"];
    secrets.cms-pswd = {
      file = "${inputs.self}/secrets/cms-pswd.age";
      path = "/run/secrets/cms-pswd";
      mode = "0400";
      owner = "kronberger";
    };
  };
}
