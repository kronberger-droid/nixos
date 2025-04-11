let
	intelNuc = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFijJelcEDGPlu9aDnjkLa4TWNXXJGeyHgw6ucANynAW intelNuc";
	t480s = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPWvSALLYRj7FIhpY+55a+dKl5s0Q3bxacot/xAqcnnQ t480s";
in
{
	"cms-pswd.age".publicKeys = [ intelNuc t480s ];
}
