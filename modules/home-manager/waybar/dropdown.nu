let screen = (swaymsg -t get_outputs | from json | where focused == true)
let width = ($screen[0].rect.width)
let height = ($screen[0].rect.height)

let w = ($width * 0.5 | math round)
let h = ($height * 0.25 | math round)

swaymsg 'for_window [instance="dropdown"] floating enable, border none, move absolute position 0px 0px'
swaymsg $"resize set ($w)px ($h)px"
swaymsg 'move scratchpad'
