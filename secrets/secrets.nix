let
	intelNucPersonal = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOQY6sum7p25iggOW0SP/4iAeecD7PQy9IMIxQm6zRU+ e12202316@student.tuwien.ac.at";
	intelNucSystem = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMkg4KKoH9S5TtsMXmPkWxl6s4KgrdiPnqr2S9FW0fDv root@nixos-personal";
	t480sPersonal = "";
	t480sSystem = "";
in
{
	"cms-pswd.age".publicKeys = [ intelNucPersonal intelNucSystem t480sPersonal t480sSystem];
}
