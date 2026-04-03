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

      # Helper function to combine multiple mkShell derivations
      combineShells = pkgs: shells:
        let
          # Extract attributes from all shells
          shellsList = builtins.map (shell: {
            buildInputs = shell.buildInputs or [];
            shellHook = shell.shellHook or "";
            # Get vscodeSettings from passthru or directly from shell
            vscodeSettings = (shell.passthru or {}).vscodeSettings or shell.vscodeSettings or {};
          }) shells;

          # Merge buildInputs (unique)
          mergedBuildInputs = pkgs.lib.lists.unique (pkgs.lib.lists.flatten
            (builtins.map (s: s.buildInputs) shellsList));

          # Concatenate shellHook
          mergedShellHook = pkgs.lib.strings.concatStringsSep "\n"
            (builtins.map (s: s.shellHook) shellsList);

          # Recursively merge vscodeSettings (later shells override earlier ones)
          mergedVscodeSettings = pkgs.lib.foldl
            (acc: shell: pkgs.lib.recursiveUpdate acc shell.vscodeSettings)
            {}
            shellsList;

        in
        pkgs.mkShell {
          buildInputs = mergedBuildInputs;
          shellHook = mergedShellHook;
          passthru = {
            vscodeSettings = mergedVscodeSettings;
          };
        };

      # Helper to create a combined shell with Nix+Markdown + base language
      makeCombined = pkgs: baseFn: nixFn: markdownFn: args:
        combineShells pkgs [
          (nixFn { })
          (markdownFn { })
          (baseFn args)
        ];

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

          # Create combined versions with Nix+Markdown
          latexCombined = makeCombined pkgs latexFn nixFn markdownFn;
          pythonCombined = makeCombined pkgs pythonFn nixFn markdownFn;
          rustCombined = makeCombined pkgs rustFn nixFn markdownFn;
          flutterCombined = makeCombined pkgs flutterFn nixFn markdownFn;

        in {
          # Main exports: Combined versions with Nix+Markdown included
          latex = latexCombined;
          python = pythonCombined;
          rust = rustCombined;
          flutter = flutterCombined;

          # Standalone versions (without Nix+Markdown) for advanced use
          latexStandalone = latexFn;
          pythonStandalone = pythonFn;
          rustStandalone = rustFn;
          flutterStandalone = flutterFn;
          nix = nixFn;
          markdown = markdownFn;

          # Utility functions
          combineShells = combineShells pkgs;
          withNixAndMarkdown = baseFn: makeCombined pkgs baseFn nixFn markdownFn;
        });
    };
}
