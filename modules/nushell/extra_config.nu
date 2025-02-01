source ~/.zoxide.nu

$env.config.show_banner = false

def flake-reload [] {
	let hostname = (hostname)
	git add .
	sudo nixos-rebuild switch --flake ~/.config/nixos#(hostname) --show-trace
}
