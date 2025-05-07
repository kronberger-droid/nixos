{ inputs, ... }:
{
  age = {
    secrets.cms-pswd = {
      file = "${inputs.self}/secrets/cms-pswd.age";
      path = "/run/secrets/cms-pswd";
      mode = "0400";
      owner = "kronberger";
    };
  };
}
