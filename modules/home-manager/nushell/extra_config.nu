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

def nanonis-sim [] {
	nohup quickemu --vm ~/Emulation/windows-11.conf o+e> /dev/null
	sleep 2sec
	exit
} 

def color-picker [] {
		echo "In 1 sec you can pick a color!"
		sleep 1sec

    let geometry = (slurp -p)

    let result = (grim -g $geometry -t ppm - | magick - -format '%[pixel:p{0,0}]' txt:-)

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

def nanonis-dev [] {
    let work_dir = "/home/kronberger/Programming/python/nanonis_tcp_test"
    
    swaymsg layout stacking
    
    nohup kitty -d $work_dir -e nix develop o+e> /dev/null
    sleep 0.5sec
    
    nohup kitty -d $work_dir -e nix develop o+e> /dev/null
    sleep 0.5sec
    
    swaymsg layout splith
    
    swaymsg layout stacking
    
    nohup kitty -d $work_dir claude o+e> /dev/null
    sleep 0.5sec
}
