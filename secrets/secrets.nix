let
	intelNucPersonal = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOQY6sum7p25iggOW0SP/4iAeecD7PQy9IMIxQm6zRU+ e12202316@student.tuwien.ac.at";
	intelNucSystem = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMkg4KKoH9S5TtsMXmPkWxl6s4KgrdiPnqr2S9FW0fDv root@nixos-personal";
	t480sPersonal = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID2pzV4sVGZ/oLOCw+cN3tF9pI4A/8yHx3/JD4b28+Rk e12202316@student.tuwien.ac.at";
	t480sSystem = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF1CKD6SvOGm1ow3C9leg2FpNX+DhLgWgimUuoEsPb7i root@t480s";
in
{
	"cms-pswd.age".publicKeys = [ intelNucPersonal intelNucSystem t480sPersonal t480sSystem];
}
