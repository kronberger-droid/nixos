let
  # Specify the directory explicitly (relative to the flake.nix or current file)
  modulesDir = ./; 

  # Define a list of files to exclude
  excludedFiles = [
    "default.nix"  # Exclude this file itself
  ];

  # Read all files in the specified directory
  files = builtins.attrNames (builtins.readDir modulesDir);

  # Filter to include only `.nix` files not in the excluded list
  nixFiles = builtins.filter (file:
    builtins.match ".+\\.nix$" file != null && !(builtins.elem file excludedFiles)
  ) files;
in
# Map each file to its full path
builtins.map (file: "${modulesDir}/${file}") nixFiles
