# Claude Code configuration shared by every account that runs it: the desktops
# (kronberger.nix), the homeserver (kronberger-server.nix) and the sandbox
# account (users/claude.nix). Split out of the user modules so they cannot
# drift: a skill added here shows up wherever `claude` runs, rather than only
# on whichever machine or account it was written on.
#
# Deliberately NOT listed in apps/default.nix. The homeserver user imports
# modules one by one and must not pull the whole apps tree (browsers, mail,
# music) onto a headless box, so both users reach this file by an explicit
# path import instead.
#
# Account-specific additions layer on top of this in the user module. The
# sandbox appends its own CLAUDE.md section there.
{
  lib,
  pkgs,
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

  # inpdf comes from the overlay in system/core/packages.nix, which the
  # homeserver does not import. Keyed on the package rather than the host so
  # every account on a desktop gets it, the Claude Code sandbox included
  # (useGlobalPkgs makes this the system's pkgs on both).
  claude.mcpServers.inpdf = lib.mkIf (pkgs ? inpdf) {
    command = "${pkgs.inpdf}/bin/inpdf";
    args = ["mcp"];
  };

  # Same overlay, same guard. Talks to the running Zotero desktop over its
  # local API (Settings -> Advanced -> "Allow other applications on this
  # computer to communicate with Zotero"), so nothing here holds a web API
  # key and the server is only useful while Zotero is open. Reads work as
  # is; writes on Zotero 10+ need a one-off `zotero-mcp authorize-local`.
  claude.mcpServers.zotero = lib.mkIf (pkgs ? zotero-mcp) {
    command = "${pkgs.zotero-mcp}/bin/zotero-mcp";
    args = ["serve"];
    env.ZOTERO_LOCAL = "true";
  };

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
