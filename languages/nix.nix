{ pkgs, ... }:
{ extraPackages ? [] }:

let
  # The settings we want to force in VS Code
  nixfmtPath = "${pkgs.nixfmt}/bin/nixfmt";
  nilPath = "${pkgs.nil}/bin/nil";
  vscodeSettings = {
    "nix.enableLanguageServer" = true;
    "nix.serverPath" = nilPath;
    "nix.formatterPath" = nixfmtPath;
    # "nix.serverSettings.nixd.formatting.command" = [ nixfmtPath ];
    "editor.formatOnSave" = true;
    "editor.defaultFormatter" = "jnoortheen.nix-ide";
  };
  settingsJson = builtins.toJSON vscodeSettings;

  # Zed LSP settings (binary path resolved from direnv-provided PATH)
  zedSettings = {
    "lsp" = {
      "nixd" = {};
    };
    # Disable Nix extension LSP management and force explicit binaries
    "languages" = {
      "Nix" = {
        "language_servers" = [ "nixd" "!nil" ];
        "formatter" = {
          "external" = {
            "command" = "nixfmt";
          };
        };
      };
    };
  };
in
pkgs.mkShell {
  buildInputs = with pkgs; [
    nixd
    statix
    nixfmt
    deadnix
  ] ++ extraPackages;

  shellHook = ''
    echo "❄️ Nix dev environment loaded"

    # 1. Create the local bin folder
    mkdir -p .bin

    # 2. Create a symlink named EXACTLY 'nixfmt' (what the extension wants)
    # We use 'nixfmt' as the source
    ln -sf "$(type -p nixfmt)" .bin/nixfmt

    # 3. FORCE this folder into the PATH of this shell session
    export PATH="$PWD/.bin:$PATH"

    # Auto-generate VS Code settings
    mkdir -p .vscode
    if [ ! -f .vscode/settings.json ] || [ "$(cat .vscode/settings.json 2>/dev/null)" != '${settingsJson}' ]; then
      echo '${settingsJson}' > .vscode/settings.json
    fi
    echo "📝 VS Code settings synchronized."

  '';
  passthru = {
    inherit vscodeSettings zedSettings;
  };
}
