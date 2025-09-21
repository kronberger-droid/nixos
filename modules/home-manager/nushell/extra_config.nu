source ~/.zoxide.nu

$env.config = {
	show_banner: false
	edit_mode: 'vi'
	keybindings: [
		# Existing keybinding
		{
			name: accept_completion
			modifier: CONTROL
			keycode: char_f
			mode: [vi_insert vi_normal]
			event: { send: HistoryHintComplete }
		}
		
		# === HELIX-STYLE KEYBINDINGS ===
		# Movement with selection (helix behavior)
		{
			name: helix_word_forward
			modifier: none
			keycode: char_w
			mode: [vi_normal]
			event: { edit: movewordright select: true }
		}
		{
			name: helix_word_backward
			modifier: none
			keycode: char_b
			mode: [vi_normal]
			event: { edit: movewordleft select: true }
		}
		{
			name: helix_word_end
			modifier: none
			keycode: char_e
			mode: [vi_normal]
			event: { edit: movewordrightend select: true }
		}
		
		# Line selection
		{
			name: helix_select_line
			modifier: none
			keycode: char_x
			mode: [vi_normal]
			event: { edit: movetolineend select: true }
		}
		
		# Select all
		{
			name: helix_select_all
			modifier: shift
			keycode: char_5
			mode: [vi_normal]
			event: { edit: selectall }
		}
		
		# Operations on selection
		{
			name: helix_delete_selection
			modifier: none
			keycode: char_d
			mode: [vi_normal]
			event: { edit: cutselection }
		}
		{
			name: helix_change_selection
			modifier: none
			keycode: char_c
			mode: [vi_normal]
			event: { edit: cutselection }
		}
		{
			name: helix_yank_selection
			modifier: none
			keycode: char_y
			mode: [vi_normal]
			event: { edit: copyselection }
		}
		
		# Paste
		{
			name: helix_paste_after
			modifier: none
			keycode: char_p
			mode: [vi_normal]
			event: { edit: paste }
		}
		{
			name: helix_paste_before
			modifier: shift
			keycode: char_p
			mode: [vi_normal]
			event: { edit: pastecutbufferbefore }
		}
		
		# Undo/Redo
		{
			name: helix_undo
			modifier: none
			keycode: char_u
			mode: [vi_normal]
			event: { edit: undo }
		}
		{
			name: helix_redo
			modifier: shift
			keycode: char_u
			mode: [vi_normal]
			event: { edit: redo }
		}
		
		# Insert modes - removed custom i binding to use nushell's default vi mode behavior
		{
			name: helix_append_after
			modifier: none
			keycode: char_a
			mode: [vi_normal]
			event: { edit: moveright }
		}
		{
			name: helix_open_below
			modifier: none
			keycode: char_o
			mode: [vi_normal]
			event: { edit: insertnewline }
		}
		{
			name: helix_open_above
			modifier: shift
			keycode: char_o
			mode: [vi_normal]
			event: { edit: insertnewline }
		}
	]
}

def flake-reload [] {
	let hostname = (hostname)
	git add .
	sudo nixos-rebuild switch --flake ~/.config/nixos#(hostname)
}

def enter [] {
	nix develop
}

def dev [project?: string] {
    if ($project == null) {
        nix develop .#dev
    } else {
        let projects_dir = $env.HOME + "/Programming"
        
        # Search for project in language subdirectories
        let found_project = (
            ls $projects_dir 
            | where type == dir 
            | get name 
            | each { |lang_dir| 
                let project_path = $"($lang_dir)/($project)"
                if ($project_path | path exists) { 
                    $project_path 
                } else { 
                    null 
                }
            } 
            | compact 
            | first
        )
        
        let work_dir = if ($project | path exists) { 
            $project | path expand 
        } else if ($found_project != null) {
            $found_project | path expand
        } else { 
            $"($env.HOME)/($project)" | path expand 
        }
        cd $work_dir
        nix develop .#dev
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
