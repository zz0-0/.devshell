{ pkgs, ... }:

{
  extraPackages ? [ ],
}:

let
  common = import ./common.nix { inherit pkgs; };
  inherit (common)
    mkShell
    writeVscodeSettings
    writeZedFragment
    mergeZedSettings
    writeLspWrapper
    ;

  # The settings we want to force in VS Code
  nixfmtPath = "${pkgs.nixfmt}/bin/nixfmt";
  nilPath = "${pkgs.nil}/bin/nil";
  nixdPath = "${pkgs.nixd}/bin/nixd";
  vscodeSettings = {
    "nix.enableLanguageServer" = true;
    "nix.serverPath" = nilPath;
    "nix.formatterPath" = nixfmtPath;
    "editor.formatOnSave" = true;
    "editor.defaultFormatter" = "jnoortheen.nix-ide";
  };
  settingsJson = builtins.toJSON vscodeSettings;

  # Zed LSP settings fragment
  zedSettings = {
    "languages" = {
      "Nix" = {
        "language_servers" = [
          "nixd"
          "nil"
        ];
        "formatter" = {
          "external" = {
            "command" = "nixfmt";
          };
        };
      };
    };
    "lsp" = {
      "nixd" = {
        "binary" = {
          "path" = "__PROJECT_DIR__/.zed/lsp/nixd";
        };
      };
      "nil" = {
        "binary" = {
          "path" = "__PROJECT_DIR__/.zed/lsp/nil";
        };
      };
    };
  };
  zedFragmentJson = builtins.toJSON zedSettings;
in
common.mkShell {
  buildInputs =
    with pkgs;
    [
      nil
      nixd
      statix
      nixfmt
      deadnix
    ]
    ++ extraPackages;

  shellHook = ''
    ${writeVscodeSettings settingsJson}
    ${writeZedFragment "nix" zedFragmentJson}
    ${writeLspWrapper {
      name = "nixd";
      command = "nixd";
    }}
    ${writeLspWrapper {
      name = "nil";
      command = "nil";
    }}
    ${mergeZedSettings}

    echo "❄️ Nix dev environment loaded"

    # Local bin folder with symlinked tools (usable outside the shell)
    mkdir -p .bin
    ln -sf "$(type -p nixfmt)" .bin/nixfmt
    export PATH="$PWD/.bin:$PATH"

    echo "📝 VS Code settings synchronized."
  '';
  passthru = {
    inherit vscodeSettings zedSettings;
  };
}
