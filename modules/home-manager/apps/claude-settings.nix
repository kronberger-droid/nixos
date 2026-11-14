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
  #
  # `excluded` drops skills by folder name. `pr` describes itself as "Use when
  # writing a PR body", which competed with github-voice for every PR and won
  # often enough to make PR bodies unpredictable. Filtering by name keeps it
  # out across flake updates.
  mattSkills = let
    manifest = builtins.fromJSON (builtins.readFile "${inputs.mattpocock-skills}/.claude-plugin/plugin.json");
    excluded = ["pr"];
    toEntry = rel: let
      clean = lib.removePrefix "./" rel;
    in
      lib.nameValuePair (builtins.baseNameOf clean) (inputs.mattpocock-skills + "/${clean}");
  in
    removeAttrs (builtins.listToAttrs (map toEntry manifest.skills)) excluded;

  # humanizer installs as its own skill and doubles as a prose-sweep
  # reference. Only SKILL.md and the licence: the rest of the repo is
  # packaging for other harnesses.
  humanizer = pkgs.linkFarm "humanizer-skill" [
    {
      name = "SKILL.md";
      path = "${inputs.humanizer}/SKILL.md";
    }
    {
      name = "LICENSE";
      path = "${inputs.humanizer}/LICENSE";
    }
  ];

  # The one Nushell skill. The hub, the verified cheatsheet and the testing
  # guide are local (skills/nushell/); the nu_scripts project's own Nushell
  # skill contributes its reference files as references/upstream/, linked from
  # the input so a flake update moves them. Its SKILL.md is not used, the local
  # one covers it, and http-transport.md is about the Nushell MCP server. The
  # MIT licence from the repo root travels with the references.
  nushellSkill = pkgs.runCommand "nushell-skill" {} ''
    cp -r ${./skills/nushell} $out
    chmod -R u+w $out
    mkdir -p $out/references/upstream
    for f in commands types-and-syntax data-analysis advanced bash-equivalents; do
      cp ${inputs.nu-scripts}/skills/nushell/references/$f.md $out/references/upstream/
    done
    cp ${inputs.nu-scripts}/LICENSE $out/references/upstream/LICENSE
    cat > $out/references/upstream/ATTRIBUTION.md <<'EOF'
    Source: https://github.com/nushell/nu_scripts/tree/main/skills/nushell
    Author: Mussar (0x4D5352), PR #1231. Merged by Daren Schroeder (fdncred).
    Later fixes: AucaCoyan, nextgenthemes. MIT licensed, see LICENSE.
    Reference files only, unchanged.
    EOF
  '';

  # prose-sweep's own files are local (the SNL-derived references are adapted
  # copies); the verbatim upstream references are linked in from the inputs
  # so a flake update moves them.
  proseSweep = pkgs.runCommand "prose-sweep-skill" {} ''
    cp -r ${./skills/prose-sweep} $out
    chmod -R u+w $out
    ln -s ${inputs.elements-of-style}/skills/writing-clearly-and-concisely/elements-of-style.md \
      $out/references/elements-of-style.md
    ln -s ${humanizer}/SKILL.md $out/references/humanizer.md
  '';
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
  claude.skills.guided-dev.content = builtins.readFile ./skills/guided-dev.md;
  claude.skills.mail.content = builtins.readFile ./skills/mail.md;

  # Folder skills, whole-folder symlinked into ~/.claude/skills/: Matt
  # Pocock's collection (see mattSkills above), the prose skills, the Nushell
  # skill, and five from Darren's skill pack that Matt's collection lacks.
  # blast-radius, show-me, resolving-merge-conflicts and the testing guide in
  # the nushell skill are his; nu-pr-review and nu-pr-recheck are his workflows
  # adapted here: Linux paths and a checkout in ~/Projects/rust, github-voice
  # instead of his voice, no Copilot badges, no memory notes, and a fresh
  # confirmation before anything is posted to GitHub.
  claude.skillDirs =
    mattSkills
    // {
      humanizer = humanizer;
      nushell = nushellSkill;
      prose-sweep = proseSweep;
      blast-radius = ./skills/blast-radius;
      show-me = ./skills/show-me;
      resolving-merge-conflicts = ./skills/resolving-merge-conflicts;
      nu-pr-review = ./skills/nu-pr-review;
      nu-pr-recheck = ./skills/nu-pr-recheck;
    };
}
