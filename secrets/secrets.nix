let
	intelNuc = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFijJelcEDGPlu9aDnjkLa4TWNXXJGeyHgw6ucANynAW intelNuc";
	t480s = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB2TReHzHuuq6PEJB6z/NxnGHhpssDYu12BgA2Ku0+yb root@nixos";
in
{
	"cms-pswd.age".publicKeys = [ intelNuc t480s ];
}
