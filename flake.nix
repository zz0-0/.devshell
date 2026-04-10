{
  description = "Multi-language dev environment flake with automatic Nix+Markdown support";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = f:
        nixpkgs.lib.genAttrs systems (system:
          f {
            inherit system nixpkgs;
            pkgs = import nixpkgs {
              inherit system;
              config = {
                allowUnfree = true;
                android_sdk.accept_license = true;
              };
            };
          }
        );

    in
    {
      lib = forAllSystems ({ pkgs, system, nixpkgs }:
        let
          # Import individual language functions
          latexFn = import ./languages/latex.nix pkgs;
          pythonFn = import ./languages/python.nix pkgs;
          rustFn = import ./languages/rust.nix pkgs;
          flutterFn = import ./languages/flutter.nix pkgs;
          nixFn = import ./languages/nix.nix pkgs;
          markdownFn = import ./languages/markdown.nix pkgs;
          postgresqlFn = import ./languages/postgresql.nix pkgs;

        in {
          # All exports are standalone - combine them in project flakes
          rust = rustFn;
          python = pythonFn;
          flutter = flutterFn;
          latex = latexFn;
          nix = nixFn;
          markdown = markdownFn;
          postgresql = postgresqlFn;
        });
    };
}
