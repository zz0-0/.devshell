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

  # Zed LSP settings fragment (relative paths, no hardcoded nix-store paths)
  zedSettings = {
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
    "lsp" = {
      "nixd" = {
        "binary" = {
          "path" = "\${PWD}/.zed/lsp/nixd";
        };
      };
    };
  };
  zedFragmentJson = builtins.toJSON zedSettings;
in
pkgs.mkShell {
  buildInputs = with pkgs; [
    nil
    nixd
    statix
    nixfmt
    deadnix
  ] ++ extraPackages;

  shellHook = ''
    echo "❄️ Nix dev environment loaded"

    # 1. Create the local bin folder
    mkdir -p .bin

    # Create symlink for nixfmt
    ln -sf "$(type -p nixfmt)" .bin/nixfmt

    # Add .bin to PATH
    export PATH="$PWD/.bin:$PATH"

    # Auto-generate VS Code settings
    mkdir -p .vscode
    if [ ! -f .vscode/settings.json ] || [ "$(cat .vscode/settings.json 2>/dev/null)" != '${settingsJson}' ]; then
      echo '${settingsJson}' > .vscode/settings.json
    fi
    echo "📝 VS Code settings synchronized."

    # Setup Zed LSP wrapper for nixd (NixOS compatible)
    mkdir -p .zed/lsp
    cat > .zed/lsp/nixd << 'NIXD_WRAPPER'
#!/usr/bin/env bash
# Reusable nixd wrapper for Zed on NixOS
# Finds the nearest .envrc and uses direnv to run nixd
set -euo pipefail
dir="$PWD"
while [[ "$dir" != "/" ]]; do
  if [[ -f "$dir/.envrc" ]]; then
    exec direnv exec "$dir" nixd "$@"
  fi
  dir="$(dirname "$dir")"
done
exec nixd "$@"
NIXD_WRAPPER
    chmod +x .zed/lsp/nixd

    # Write Zed settings fragment for merging
    mkdir -p .zed/lsp-config
    echo '${zedFragmentJson}' > .zed/lsp-config/nix.json

    # Merge all Zed settings fragments into .zed/settings.json
    if command -v node &>/dev/null; then
      node -e "
        const fs = require('fs');
        const path = require('path');
        const configDir = '.zed/lsp-config';
        const fragments = [];
        if (fs.existsSync(configDir)) {
          fs.readdirSync(configDir).forEach(f => {
            if (f.endsWith('.json')) {
              try {
                fragments.push(JSON.parse(fs.readFileSync(path.join(configDir, f), 'utf8')));
              } catch (e) {
                console.error('Failed to parse fragment:', f, e.message);
              }
            }
          });
        }
        function deepMerge(target, source) {
          const output = Object.assign({}, target);
          if (typeof target === 'object' && typeof source === 'object') {
            Object.keys(source).forEach(key => {
              if (typeof source[key] === 'object' && source[key] !== null && !Array.isArray(source[key])) {
                output[key] = deepMerge(target[key] || {}, source[key]);
              } else {
                output[key] = source[key];
              }
            });
          }
          return output;
        }
        const merged = fragments.reduce((acc, frag) => deepMerge(acc, frag), {});
        fs.writeFileSync('.zed/settings.json', JSON.stringify(merged, null, 2) + '\n');
        console.log('✅ Zed settings merged from', fragments.length, 'fragment(s)');
      "
    else
      echo '${zedFragmentJson}' > .zed/settings.json
      echo "⚠️  Node not available. Using Nix Zed settings only."
    fi

  '';
  passthru = {
    inherit vscodeSettings zedSettings;
  };
}
