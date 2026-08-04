# Claude Code configuration shared by every host that runs it — the desktops
# (kronberger.nix) and the homeserver (kronberger-server.nix). Split out of the
# user modules so the two cannot drift: a skill added here shows up wherever
# `claude` runs, rather than only on whichever machine it was written on.
#
# Deliberately NOT listed in apps/default.nix. That file is imported wholesale
# by the desktop user, but also by the media user, which is meant to have no
# claude/ai at all (see users/media.nix). Both real users pull this in by an
# explicit path import instead.
#
# Host-specific additions layer on top of this in the user module. The desktop
# adds the inpdf MCP server there, because `pkgs.inpdf` comes from the overlay
# in system/core/packages.nix, which the homeserver does not import.
{
  lib,
  inputs,
  ...
}: let
  # Matt Pocock's skills, derived straight from the repo's plugin manifest so
  # the set tracks upstream exactly (a flake update adds/removes skills with it).
  # plugin.json lists relative paths like "./skills/engineering/tdd"; we map each
  # to { <foldername> = <store path to that folder>; } for claude.skillDirs.
  mattSkills = let
    manifest = builtins.fromJSON (builtins.readFile "${inputs.mattpocock-skills}/.claude-plugin/plugin.json");
    toEntry = rel: let
      clean = lib.removePrefix "./" rel;
    in
      lib.nameValuePair (builtins.baseNameOf clean) (inputs.mattpocock-skills + "/${clean}");
  in
    builtins.listToAttrs (map toEntry manifest.skills);
in {
  imports = [./claude.nix];

  claude.statusline.enable = true;
  claude.plugins = [
    "context7@claude-plugins-official"
    "github@claude-plugins-official"
    "explanatory-output-style@claude-plugins-official"
  ];
  claude.claudeMd = builtins.readFile ./claude-md.md;

  claude.skills.rust-to-cpp.content = builtins.readFile ./skills/rust-to-cpp.md;
  claude.skills.vault.content = builtins.readFile ./skills/vault.md;
  claude.skills.typst.content = builtins.readFile ./skills/typst.md;
  claude.skills.scientific-writing.content = builtins.readFile ./skills/scientific-writing.md;
  claude.skills.commit-writer.content = builtins.readFile ./skills/commit-writer.md;
  claude.skills.github-voice.content = builtins.readFile ./skills/github-voice.md;

  # Matt Pocock's skills collection (github:mattpocock/skills), whole-folder
  # symlinked into ~/.claude/skills/. See mattSkills above for derivation.
  claude.skillDirs = mattSkills;
}
