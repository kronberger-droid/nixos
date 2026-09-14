# Deliberately unconfigured. Helix is the editor (editors/helix.nix sets
# defaultEditor); this exists so `vi` and `vim` resolve to something usable
# on a box where muscle memory or a tool's hardcoded `vim` wins, and stays a
# stock neovim on purpose: a configured second editor would drift.
{...}: {
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    withRuby = false;
    withPython3 = false;
  };
}
