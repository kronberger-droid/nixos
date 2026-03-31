{pkgs, ...}: {
  home.packages = with pkgs; [
    dprint
  ];

  home.file.".dprint.json".text = builtins.toJSON {
    lineWidth = 120;
    indentWidth = 2;
    plugins = [
      "${pkgs.dprint-plugins.dprint-plugin-markdown}/plugin.wasm"
    ];
  };
}
