{
  description = "Multi-language dev environment flake for NixOS + direnv workflows";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
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

      # Scaffold a template (flake.nix + .envrc + .gitignore) for a
      # single-language project, so `nix flake init -t devshell#<lang>` works.
      mkTemplate =
        { name, description }:
        {
          inherit description;
          path = ./templates/${name};
        };

    in
    {
      lib = forAllSystems (
        { pkgs, ... }: {
          # All exports are standalone - combine them in project flakes
          rust = import ./languages/rust.nix { inherit pkgs; };
          bevy = import ./languages/bevy.nix { inherit pkgs; };
          python = import ./languages/python.nix { inherit pkgs; };
          flutter = import ./languages/flutter.nix { inherit pkgs; };
          latex = import ./languages/latex.nix { inherit pkgs; };
          nix = import ./languages/nix.nix { inherit pkgs; };
          markdown = import ./languages/markdown.nix { inherit pkgs; };
          postgresql = import ./languages/postgresql.nix { inherit pkgs; };
          java = import ./languages/java.nix { inherit pkgs; };
          video = import ./languages/video.nix { inherit pkgs; };
          web = import ./languages/web.nix { inherit pkgs; };
        }
      );

      formatter = forAllSystems ({ pkgs, ... }: pkgs.nixfmt-tree);

      # `nix run github:zz0-0/devshell#new -- <lang> <dir>`
      apps = forAllSystems (
        { pkgs, ... }:
        {
          new = {
            type = "app";
            program = "${
              pkgs.writeShellApplication {
                name = "new";
                runtimeInputs = [ pkgs.nix pkgs.direnv ];
                text = ''
                  export DEVSHELL_ROOT="${self}"
                  ${builtins.readFile ./scripts/new-project.sh}
                '';
              }
            }/bin/new";
          };
        }
      );

      # Editing this repo itself gets the same Nix tooling as projects.
      devShells = forAllSystems (
        { pkgs, ... }:
        {
          default = (import ./languages/nix.nix { inherit pkgs; }) { };
        }
      );

      # Eval-check: forces evaluation (not building) of every language shell so
      # `nix flake check` catches errors without downloading the world.
      checks = forAllSystems (
        { pkgs, system, ... }:
        let
          lib = self.lib.${system};
          shells = [
            (lib.rust { })
            (lib.bevy { })
            (lib.python { })
            (lib.flutter { })
            (lib.latex { })
            (lib.nix { })
            (lib.markdown { })
            (lib.postgresql { })
            (lib.java { })
            (lib.video { })
          ];
        in
        {
          # Force evaluation of every language shell without retaining their
          # .drv paths as store references. Keeping the context makes
          # `nix flake check` validate those paths, which fails spuriously
          # after a GC even though evaluation is fine.
          eval = pkgs.writeText "devshell-eval.txt" (
            builtins.concatStringsSep "\n" (map (s: builtins.unsafeDiscardStringContext s.drvPath) shells)
          );

          # Build the lightweight shells for real. The heavy language shells
          # remain eval-only so `nix flake check` stays practical.
          build-nix = lib.nix { };
          build-markdown = lib.markdown { };
        }
      );

      templates = {
        rust = mkTemplate {
          name = "rust";
          description = "Rust project";
        };
        bevy = mkTemplate {
          name = "bevy";
          description = "Bevy game project";
        };
        python = mkTemplate {
          name = "python";
          description = "Python project";
        };
        flutter = mkTemplate {
          name = "flutter";
          description = "Flutter project";
        };
        latex = mkTemplate {
          name = "latex";
          description = "LaTeX project";
        };
        nix = mkTemplate {
          name = "nix";
          description = "Nix project";
        };
        markdown = mkTemplate {
          name = "markdown";
          description = "Markdown project";
        };
        postgresql = mkTemplate {
          name = "postgresql";
          description = "PostgreSQL project";
        };
        java = mkTemplate {
          name = "java";
          description = "Java project";
        };
        video = mkTemplate {
          name = "video";
          description = "Video production project";
        };
      };
    };
}
