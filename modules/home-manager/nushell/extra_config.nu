source ~/.zoxide.nu

$env.config.show_banner = false

def flake-reload [] {
	let hostname = (hostname)
	git add .
	sudo nixos-rebuild switch --flake ~/.config/nixos#(hostname)
}

def dev [] {
	nix develop
}

def "dev thesis" [] {
	cd ~/GitHub/Thesis-Latex-Source
	dev
}

def "dev python" [] {
	cd ~/Programming/python
	dev
	python	
}

def "dev rust" [] {
  let current_dir = (~/.config/nixos/modules/home-manager/kitty/cwd.sh)

  let project_name = ($current_dir | path basename | to text)

  nix develop ..#($project_name)
}

def color-picker [] {
		echo "In 1 sec you can pick a color!"
		sleep 1sec
    # Use slurp to let you select a screen area
    let geometry = (slurp -p)

    # Capture the picked area as a ppm image with grim,
    # then use ImageMagick to output pixel information from (0,0)
    let result = (grim -g $geometry -t ppm - | magick - -format '%[pixel:p{0,0}]' txt:-)

    # Process the result to extract tokens
    let tokens = (
        $result 
        | split row "\n" 
        | compact --empty 
        | get 1 
        | split row " " 
        | compact --empty
    )

    echo [[type value]; [RGB ($tokens | get 1 | str replace -ra "[()]" "")] [HEX ($tokens | get 2)] ]
}
