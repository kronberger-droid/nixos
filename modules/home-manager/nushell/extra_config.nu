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

def --env dev-setup [work_dir: string] {
    swaymsg layout splith
    
    swaymsg layout stacking
    
    swaymsg exec $"kitty --working-directory=($work_dir) -e nu -c 'cd ($work_dir); nix develop'"
    sleep 0.5sec
    
    swaymsg focus parent
    
    swaymsg exec $"kitty --working-directory=($work_dir) -e bash -c 'cd ($work_dir) && nix develop .#dev --command bash -c \"clear && claude\"'"
    sleep 0.5sec

    swaymsg layout stacking
    
    swaymsg focus left
    cd $work_dir
    nix develop .#dev --command hx
}

def dev [project?: string] {
    if ($project == null) {
        nix develop
    } else if ($project == "nanonis") {
        dev-setup "/home/kronberger/Programming/python/nanonis_tcp_test"
    } else {
        let work_dir = if ($project | path exists) { 
            $project | path expand 
        } else { 
            $"($env.HOME)/($project)" | path expand 
        }
        dev-setup $work_dir
    }
}

def sim [project: string] {
    if ($project == "nanonis") {
        nohup quickemu --vm ~/Emulation/windows-11.conf o+e> /dev/null
        sleep 2sec
        exit
    } else {
        echo $"Unknown simulation project: ($project)"
    }
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
