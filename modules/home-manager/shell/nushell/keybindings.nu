# Nushell keybindings.
#
# Note: the selection-first editing keys (w/b/e/x/d/c/y/p/u/a/o/…) that used to
# live here were a *vi-mode emulation* of Helix. They're gone now that we run
# the real reedline Helix edit mode (edit_mode = 'helix'), which implements that
# behaviour in the engine. What remains are genuine nushell bindings; they
# target helix modes (and vi, so they survive a switch back to edit_mode 'vi').

export def get_keybindings [] {
    [
        {
            name: accept_completion
            modifier: CONTROL
            keycode: char_f
            mode: [helix_insert helix_normal vi_insert vi_normal]
            event: { send: HistoryHintComplete }
        }
    ]
}
