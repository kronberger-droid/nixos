# zotero-mcp (github:54yyyu/zotero-mcp): the MCP server that lets Claude Code
# read and search the Zotero library. Not in nixpkgs, and two of its
# dependencies fall short there, so this file carries all three:
#
# - pyzotero: nixpkgs ships 1.13.0, upstream needs >=1.14.0 for the local-API
#   write path (authorize_local, the server_id/local_api_key constructor args).
#   1.14.0 is the last release on httpx; 1.15 moved to httpx2 and wants a
#   newer one (>=2.12) than nixpkgs has (2.9), so it stays at 1.14.0 until
#   nixpkgs catches up. zotero-mcp handles either HTTP library.
# - pdf-inspector: a Rust extension with no sdist build story outside maturin,
#   which nixpkgs does not carry as a Python build-system. Upstream publishes
#   abi3 manylinux wheels, so the wheel is installed as-is and patchelf'd.
#
# Consumed by claude-settings.nix through `pkgs ? zotero-mcp`, the same guard
# inpdf uses: the homeserver never imports this overlay and gets no entry.
{
  lib,
  stdenv,
  python3,
  fetchFromGitHub,
  fetchPypi,
  autoPatchelfHook,
}: let
  python = python3.override {
    packageOverrides = self: super: {
      pyzotero = super.pyzotero.overridePythonAttrs (old: rec {
        version = "1.14.0";
        src = fetchFromGitHub {
          owner = "urschrei";
          repo = "pyzotero";
          tag = "v${version}";
          hash = "sha256-1CnGiE94WvoY73wSmtaDH3G+31dl2QjsV6o6jcpAFKc=";
        };
        # Same unpin nixpkgs applies to 1.13.0, for the range 1.14.0 declares.
        postPatch = ''
          substituteInPlace pyproject.toml \
            --replace-fail "uv_build>=0.8.14,<0.12.0" "uv-build"
        '';
        # Same dependency set as 1.13.0; the override is for version and
        # source only. Tests are skipped: they are pinned to 1.13's mocks and
        # this client is consumed by zotero-mcp alone.
        doCheck = false;
      });

      pdf-inspector = let
        wheels = {
          x86_64-linux = {
            platform = "manylinux_2_17_x86_64.manylinux2014_x86_64";
            hash = "sha256-33bdEAUEtwXOku8sZo8VLwUnfZQqvZSn0/JSy1RI1W0=";
          };
          aarch64-linux = {
            platform = "manylinux_2_17_aarch64.manylinux2014_aarch64";
            hash = "sha256-ebozsiQCm2jtvTDn9twDT3MGY3SboL6hLlhzsxQ1yig=";
          };
        };
        wheel =
          wheels.${stdenv.hostPlatform.system}
          or (throw "pdf-inspector: no wheel for ${stdenv.hostPlatform.system}");
      in
        self.buildPythonPackage rec {
          pname = "pdf_inspector";
          version = "0.2.6";
          format = "wheel";

          src = fetchPypi {
            inherit pname version format;
            dist = "cp38";
            python = "cp38";
            abi = "abi3";
            inherit (wheel) platform hash;
          };

          nativeBuildInputs = [autoPatchelfHook];
          buildInputs = [stdenv.cc.cc.lib];

          pythonImportsCheck = ["pdf_inspector"];

          meta = {
            description = "PDF text extraction (Rust, abi3 wheel)";
            homepage = "https://github.com/firecrawl/pdf-inspector";
            license = lib.licenses.mit;
            platforms = builtins.attrNames wheels;
          };
        };
    };
  };
in
  python.pkgs.buildPythonApplication rec {
    pname = "zotero-mcp";
    version = "0.13.0";
    pyproject = true;

    src = fetchFromGitHub {
      owner = "54yyyu";
      repo = "zotero-mcp";
      tag = "v${version}";
      hash = "sha256-xL54SbaAczkwk4tkan+wVVTv9ACKIC6hcAADI2GTnxk=";
    };

    build-system = with python.pkgs; [hatchling];

    # The base set only. The `semantic` extra (chromadb, sentence-transformers,
    # torch behind it) and `pdf` (pymupdf) are opt-in upstream too; add them
    # here if semantic search or page-layout tools turn out to be wanted.
    dependencies = with python.pkgs; [
      pyzotero
      python-dotenv
      pdf-inspector
      markdownify
      pydantic
      requests
      fastmcp
      httpx
      unidecode
      bibtexparser
    ];

    # Tests talk to a Zotero instance and a local HTTP server fixture.
    doCheck = false;

    pythonImportsCheck = ["zotero_mcp" "zotero_mcp.server"];

    meta = {
      description = "Model Context Protocol server for Zotero";
      homepage = "https://github.com/54yyyu/zotero-mcp";
      changelog = "https://github.com/54yyyu/zotero-mcp/blob/v${version}/CHANGELOG.md";
      license = lib.licenses.mit;
      mainProgram = "zotero-mcp";
      platforms = ["x86_64-linux" "aarch64-linux"];
    };
  }
