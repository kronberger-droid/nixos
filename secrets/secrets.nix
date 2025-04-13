let
	intelNuc= "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG2nXGswPYhgVX6zwQAg3Wk8pfVw64pY+wIRIUoSyXYr root@intelNuc";
	t480s = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB2TReHzHuuq6PEJB6z/NxnGHhpssDYu12BgA2Ku0+yb root@nixos";
in
{
	"cms-pswd.age".publicKeys = [ intelNuc t480s ];
}
