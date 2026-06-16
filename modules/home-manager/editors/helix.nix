{
  pkgs,
  config,
  lib,
  ...
}: let
  scheme = config.scheme;
  ansi = config.ansi;

  # Generated palette theme — maps scheme colors to names used by base16_transparent
  base16PaletteTheme = pkgs.writeText "base16-nix.toml" ''
    inherits = "base16_transparent"

    [palette]
    # Generic names (used by base16_transparent's style rules). The ANSI-slot
    # names are sourced from config.ansi (shared with kitty + rio); light-gray
    # is base04, a base16 ramp color with no ANSI slot. Note light-red is the
    # bright-red slot = base09 (orange), so base16_transparent's variable/
    # markup.list pick that up; errors are pinned back to red in the overlay.
    black = "#${ansi.black}"
    red = "#${ansi.red}"
    green = "#${ansi.green}"
    yellow = "#${ansi.yellow}"
    blue = "#${ansi.blue}"
    magenta = "#${ansi.magenta}"
    cyan = "#${ansi.cyan}"
    white = "#${ansi.white}"
    gray = "#${ansi."bright-black"}"
    light-gray = "#${scheme.base04}"
    light-red = "#${ansi."bright-red"}"
    light-green = "#${ansi."bright-green"}"
    light-yellow = "#${ansi."bright-yellow"}"
    light-blue = "#${ansi."bright-blue"}"
    light-magenta = "#${ansi."bright-magenta"}"
    light-cyan = "#${ansi."bright-cyan"}"
    # Base16 names (for overlay use)
    base00 = "#${scheme.base00}"
    base01 = "#${scheme.base01}"
    base02 = "#${scheme.base02}"
    base03 = "#${scheme.base03}"
    base04 = "#${scheme.base04}"
    base05 = "#${scheme.base05}"
    base06 = "#${scheme.base06}"
    base07 = "#${scheme.base07}"
    base08 = "#${scheme.base08}"
    base09 = "#${scheme.base09}"
    base0A = "#${scheme.base0A}"
    base0B = "#${scheme.base0B}"
    base0C = "#${scheme.base0C}"
    base0D = "#${scheme.base0D}"
    base0E = "#${scheme.base0E}"
    base0F = "#${scheme.base0F}"
  '';

  livePath = config.helix.liveConfigPath;
  # Editable helix config: when a live repo checkout is configured, symlink
  # straight into it (edit without rebuild); otherwise copy from the store
  # (e.g. nix-on-droid, where the repo isn't checked out at a fixed path).
  mkConfigSource = {
    repoPath,
    storePath,
  }:
    if livePath != null
    then config.lib.file.mkOutOfStoreSymlink "${livePath}/${repoPath}"
    else storePath;

  # When false, drop the heavyweight language tooling (Typst, Python, CSV,
  # GLSL, PDF viewer, compilers) and keep only Nix + Markdown + Rust editing.
  full = !config.helix.minimal;
in {
  imports = [
    ./helix/dprint.nix
  ];

  options.helix = {
    liveConfigPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "/home/kronberger/.config/nixos";
      description = ''
        Path to a live checkout of this nixos repo. When set, helix's editable
        config files are out-of-store symlinks into it (edit without rebuild).
        Set to null where the repo isn't checked out at a fixed path (e.g.
        nix-on-droid) to copy the files from the store instead.
      '';
    };

    minimal = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Trim the language tooling to a lean core (Nix + Markdown + Rust
        editing), omitting heavyweight servers/formatters (Typst, Python,
        CSV, GLSL, PDF viewer, compilers). For constrained targets like
        nix-on-droid. Also prunes the matching languages.toml entries so the
        omitted tools don't get pulled into the closure by store-path refs.
      '';
    };
  };

  config = {
    home = {
      # Order preserved so the full build's home profile is byte-identical;
      # full-only packages are interleaved via optionals.
      packages = with pkgs;
        [
          # Nix
          nil
          statix
          deadnix
          alejandra
        ]
        ++ lib.optionals full [
          # Typst
          typst
          typstyle
          typst-live
          tinymist
        ]
        ++ [
          # Markdown
          rumdl
          markdown-oxide

          # Spellcheck
          harper
        ]
        ++ lib.optionals full [
          # PDF Viewer
          zathura

          # CSV
          prettier

          # General Compilers
          gcc

          # Rust
          bacon
          rust-script

          # Python
          ruff
          pyright

          # OpenGL
          glsl_analyzer

          # JSON / web (Biome: LSP + formatter)
          biome
        ];

      file = {
        # Nix-generated palette (inherits base16_transparent + scheme colors)
        ".config/helix/themes/base16-nix.toml".source = base16PaletteTheme;
        # Editable files — live symlink on desktop, store copy elsewhere
        ".config/helix/themes/custom-base16.toml".source = mkConfigSource {
          repoPath = "modules/home-manager/editors/helix/custom-base16.toml";
          storePath = ./helix/custom-base16.toml;
        };
        ".config/helix/ignore".source = mkConfigSource {
          repoPath = "modules/home-manager/editors/helix/ignore";
          storePath = ./helix/ignore;
        };
        ".config/harper/dictionary.txt".source = mkConfigSource {
          repoPath = "modules/home-manager/editors/helix/harper_dict.txt";
          storePath = ./helix/harper_dict.txt;
        };
        ".config/rumdl/rumdl.toml".source = mkConfigSource {
          repoPath = "modules/home-manager/editors/helix/rumdl.toml";
          storePath = ./helix/rumdl.toml;
        };
      };
    };

    programs.helix = {
      enable = true;
      defaultEditor = true;
      settings = {
        theme = "custom-base16";
        editor = {
          text-width = 70;
          scrolloff = 8;
          color-modes = true;
          bufferline = "multiple";
          soft-wrap = {
            enable = true;
          };
          line-number = "relative";
          cursor-shape = {
            insert = "bar";
            normal = "block";
            select = "underline";
          };
          statusline = {
            left = [
              "mode"
              "spinner"
              "version-control"
              "file-modification-indicator"
              "file-name"
            ];
            right = [
              "diagnostics"
              "selections"
              "position"
              "file-encoding"
            ];
          };
          file-picker = {
            hidden = false;
          };
          # Only warnings/errors get trailing end-of-line text; harper's
          # hint-level findings stay as a faint underline only (see theme).
          end-of-line-diagnostics = "warning";
          inline-diagnostics = {
            cursor-line = "warning";
          };
          lsp = {
            auto-signature-help = false;
            display-messages = false;
            display-inlay-hints = false;
          };
        };
        keys.normal = {
          space.space = "file_picker";
          ret = {
            ret = ":w";
            q = ":q";
            w = ":wq";
            r = ":reload-all";
          };
          # Ctrl-x: browse with yazi, open the picked file in *this* helix.
          # X for "explorer", matching the niri Mod+Shift+X yazi binding.
          # Helix has no RPC, so the round-trip goes through a chooser file:
          # :insert-output hands yazi the terminal (and inserts nothing, since
          # --chooser-file sends the path to the temp file, not stdout); the
          # printf restores the escape sequences yazi clobbered; :open reads
          # the path back; the mouse toggle forces a clean redraw.
          "C-x" = [
            ":sh rm -f /tmp/helix-yazi-chooser"
            ":insert-output yazi \"%{buffer_name}\" --chooser-file=/tmp/helix-yazi-chooser"
            ":sh printf \"\\x1b[?1049h\\x1b[?2004h\" > /dev/tty"
            ":open %sh{cat /tmp/helix-yazi-chooser}"
            ":redraw"
            ":set mouse false"
            ":set mouse true"
          ];
        };
      };

      languages = {
        # Order preserved (csv, markdown, rust, typst, python, nix) so the
        # generated languages.toml is byte-identical on full builds; the
        # full-only entries are interleaved via optionals.
        language =
          lib.optionals full [
            {
              name = "csv";
              formatter = {
                command = "${pkgs.prettier}/bin/prettier";
                args = ["--parser" "csv"];
              };
              auto-format = true;
            }
          ]
          ++ [
            {
              name = "markdown";
              # rumdl stays as the formatter below; dropped as a language
              # server to cut its diagnostics noise (harper handles prose).
              language-servers = [
                "harper"
              ];
              formatter = {
                command = "${pkgs.rumdl}/bin/rumdl";
                args = ["fmt" "-"];
              };
              auto-format = true;
            }
            {
              name = "rust";
              language-servers = [
                "rust-analyzer"
                "harper"
              ];
            }
          ]
          ++ lib.optionals full [
            {
              name = "typst";
              language-servers = [
                "tinymist"
                "harper"
              ];
              formatter = {
                command = "${pkgs.typstyle}/bin/typstyle";
              };
              auto-format = true;
            }
            {
              name = "python";
              language-servers = ["pyright"];
              formatter = {
                command = "${pkgs.ruff}/bin/ruff";
                args = ["format" "-"];
              };
              auto-format = true;
            }
            {
              name = "json";
              language-servers = ["biome"];
              formatter = {
                command = "${pkgs.biome}/bin/biome";
                args = ["format" "--stdin-file-path" "file.json"];
              };
              auto-format = true;
            }
            {
              name = "jsonc";
              language-servers = ["biome"];
              formatter = {
                command = "${pkgs.biome}/bin/biome";
                args = ["format" "--stdin-file-path" "file.jsonc"];
              };
              auto-format = true;
            }
          ]
          ++ [
            {
              name = "nix";
              language-servers = ["nil"];
              formatter = {
                command = "${pkgs.alejandra}/bin/alejandra";
                args = ["--quiet"];
              };
              auto-format = true;
            }
          ];
        language-server =
          {
            nil = {
              command = "${pkgs.nil}/bin/nil";
              file-types = ["nix"];
            };
            rust-analyzer = {
              command = "rust-analyzer";
              config = {
                check.command = "clippy";
              };
            };
            harper = {
              command = "${pkgs.harper}/bin/harper-ls";
              args = ["--stdio"];
              config = {
                harper-ls = {
                  userDictPath = "~/.config/harper/dictionary.txt";
                  # Render findings as subtle hints, not loud warnings — the
                  # main "quiet" knob. With end-of-line-diagnostics = "hint"
                  # these only surface at the cursor line.
                  diagnosticSeverity = "hint";
                  # Keep spell checking; silence the prose-style nags (which
                  # also fire on rust comments). Drop this block for grammar.
                  linters = {
                    SpellCheck = true;
                    SpelledNumbers = false;
                    SentenceCapitalization = false;
                    LongSentences = false;
                    RepeatedWords = false;
                  };
                };
              };
            };

            rumdl = {
              command = "${pkgs.rumdl}/bin/rumdl";
              args = ["server" "--stdio"];
            };
          }
          // lib.optionalAttrs full {
            pyright = {
              command = "${pkgs.pyright}/bin/pyright-langserver";
              args = ["--stdio"];
              config = {
                python.analysis = {
                  typeCheckingMode = "basic";
                };
              };
            };
            biome = {
              command = "${pkgs.biome}/bin/biome";
              args = ["lsp-proxy"];
            };
          };
      };
    };
  };
}
