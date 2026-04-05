{ pkgs, ... }:
{ extraPackages ? [] }:

let
  texEnv = pkgs.texlive.combine {
    inherit (pkgs.texlive)
      scheme-medium
      collection-latexextra
      collection-fontsrecommended
      latexmk
      biblatex
      biber;
  };

  # Calculate the absolute path to the bin directory in the Nix store
  texBinPath = "${texEnv}/bin";

  vscodeSettings = {
    "latex-workshop.view.pdf.viewer" = "tab";
    "latex-workshop.latex.autoBuild.run" = "onSave";
    "latex-workshop.latex.recipe.default" = "latexmk";

    # This is the magic part: We tell the extension exactly where to look
    "latex-workshop.latex.tools" = [
      {
        "name" = "latexmk";
        "command" = "${texBinPath}/latexmk"; # Absolute path
        "args" = [
          "-shell-escape"
          "-synctex=1"
          "-interaction=nonstopmode"
          "-file-line-error"
          "-pdf"
          "-outdir=build"
          "%DOC%"
        ];
        "env" = {
          "PATH" = "${texBinPath}:${pkgs.coreutils}/bin"; # Ensure it has basics
        };
      }
    ];
  };
in
pkgs.mkShell {
  buildInputs = [
    texEnv
    pkgs.texlab
    pkgs.pandoc
    pkgs.ghostscript
  ] ++ extraPackages;

  shellHook = ''
    echo "📄 LaTeX environment initialized"
    mkdir -p .vscode
    if [ ! -f .vscode/settings.json ] || [ "$(cat .vscode/settings.json 2>/dev/null)" != '${builtins.toJSON vscodeSettings}' ]; then
      echo '${builtins.toJSON vscodeSettings}' > .vscode/settings.json
    fi

    # Setup Zed LSP wrapper for texlab (NixOS compatible)
    mkdir -p .zed/lsp
    cat > .zed/lsp/texlab << 'TEXLAB_WRAPPER'
#!/usr/bin/env bash
# Reusable texlab wrapper for Zed on NixOS
# Uses the wrapper's own location to find the project root (two levels up from .zed/lsp/)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "''${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Use direnv to run texlab with the correct environment
exec direnv exec "$PROJECT_DIR" texlab "$@"
TEXLAB_WRAPPER
    chmod +x .zed/lsp/texlab

    # Write Zed settings fragment for merging
    mkdir -p .zed/lsp-config
    echo '${zedFragmentJson}' > .zed/lsp-config/latex.json

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
      echo "⚠️  Node not available. Using LaTeX Zed settings only."
    fi
  '';

  # Zed LSP settings fragment (relative paths, no hardcoded nix-store paths)
  zedSettings = {
    "languages" = {
      "Latex" = {
        "format_on_save" = "on";
        "language_servers" = ["texlab"];
      };
    };
    "lsp" = {
      "texlab" = {
        "binary" = {
          "path" = "__PROJECT_DIR__/.zed/lsp/texlab";
        };
      };
    };
  };
  zedFragmentJson = builtins.toJSON zedSettings;

  passthru = {
    inherit vscodeSettings zedSettings;
  };
}
