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
        "language_servers" = [ "nixd" "nil" ];
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
# Uses the wrapper's own location to find the project root (two levels up from .zed/lsp/)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "''${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Use direnv to run nixd with the correct environment
# Redirect stderr to /dev/null to suppress shellHook output that interferes with LSP
exec direnv exec "$PROJECT_DIR" nixd "$@" 2>/dev/null 2>/dev/null
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
        // Replace __PROJECT_DIR__ placeholder with actual project directory
        const projectDir = process.env.PWD || process.cwd();
        const settingsStr = JSON.stringify(merged, null, 2).replace(/__PROJECT_DIR__/g, projectDir);
        fs.writeFileSync('.zed/settings.json', settingsStr + '\n');
        console.log('✅ Zed settings merged from', fragments.length, 'fragment(s)');
      "
    else
      echo '${zedFragmentJson}' | sed "s|__PROJECT_DIR__|$PWD|g" > .zed/settings.json
      echo "⚠️  Node not available. Using Nix Zed settings only."
    fi

  '';
  passthru = {
    inherit vscodeSettings zedSettings;
  };
}
