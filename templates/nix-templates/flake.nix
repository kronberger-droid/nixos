{
  description = "Personal flake templates";

  outputs = {self, ...}: {
    templates = {
      rust-gui = {
        path = ./rust-gui;
        description = "Rust project with GUI (eframe/egui), CLI, and Windows cross-compilation";
      };

      rust-cli = {
        path = ./rust-cli;
        description = "Rust CLI project with cross-compilation";
      };
    };
  };
}
