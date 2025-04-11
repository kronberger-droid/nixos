let
	intelNuc = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG2nXGswPYhgVX6zwQAg3Wk8pfVw64pY+wIRIUoSyXYr root@intelNuc";
	t480s = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID2pzV4sVGZ/oLOCw+cN3tF9pI4A/8yHx3/JD4b28+Rk e12202316@student.tuwien.ac.at";
in
{
	"cms-pswd.age".publicKeys = [ intelNuc t480s ];
}
