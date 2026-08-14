#!@nu@/bin/nu -n

# Disabled exactly when the state file exists; rotation-toggle.nu owns it.
let disabled = ($env.HOME | path join ".cache" "rotation-state" | path exists)

if $disabled {
  {icon: "disabled", alt: "disabled", tooltip: "Auto-rotation Disabled", class: "disabled"}
} else {
  {icon: "enabled", alt: "enabled", tooltip: "Auto-rotation Enabled", class: "enabled"}
} | to json --raw
