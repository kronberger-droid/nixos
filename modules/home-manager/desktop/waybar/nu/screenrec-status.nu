#!@nu@/bin/nu -n

let recording = ((^@procps@/bin/pgrep -x wl-screenrec | complete).exit_code == 0)

if $recording {
  {text: "REC", class: "recording"} | to json --raw
} else {
  # Empty output hides the module.
  ""
}
