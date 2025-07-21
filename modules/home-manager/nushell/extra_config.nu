source ~/.zoxide.nu

$env.config = {
	show_banner: false
	edit_mode: 'vi'
	keybindings: [
		{
			name: accept_completion
			modifier: CONTROL
			keycode: char_f
			mode: [vi_insert vi_normal]
			event: { send: HistoryHintComplete }
		}
	]
}

def flake-reload [] {
	let hostname = (hostname)
	git add .
	sudo nixos-rebuild switch --flake ~/.config/nixos#(hostname)
}

def dev [] {
	nix develop
}

def nanonis [] {
	quickemu --vm ~/Emulation/windows-11.conf --sound-card none
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
