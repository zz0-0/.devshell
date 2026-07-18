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

      # Compute version from flake rev (changes on every commit)
      # Falls back to lastModified if rev is null (e.g., dirty tree)
      devshellVersion = if self ? rev && self.rev != null then self.rev else toString self.lastModified;

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
          # Import individual language functions with version
          latexFn = import ./languages/latex.nix { pkgs = pkgs; devshellVersion = devshellVersion; };
          pythonFn = import ./languages/python.nix { pkgs = pkgs; devshellVersion = devshellVersion; };
          rustFn = import ./languages/rust.nix { pkgs = pkgs; devshellVersion = devshellVersion; };
          flutterFn = import ./languages/flutter.nix { pkgs = pkgs; devshellVersion = devshellVersion; };
          nixFn = import ./languages/nix.nix { pkgs = pkgs; devshellVersion = devshellVersion; };
          markdownFn = import ./languages/markdown.nix { pkgs = pkgs; devshellVersion = devshellVersion; };
          postgresqlFn = import ./languages/postgresql.nix { pkgs = pkgs; devshellVersion = devshellVersion; };
          javaFn = import ./languages/java.nix { pkgs = pkgs; devshellVersion = devshellVersion; };

        in {
          # All exports are standalone - combine them in project flakes
          rust = rustFn;
          python = pythonFn;
          flutter = flutterFn;
          latex = latexFn;
          nix = nixFn;
          markdown = markdownFn;
          postgresql = postgresqlFn;
          java = javaFn;
        });
    };
}
