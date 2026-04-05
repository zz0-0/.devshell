
{ pkgs, ... }:
{ extraPackages ? [] }:

let
  # Define the python suite once to ensure consistency
  pythonEnv = pkgs.python3;
  pythonPkgs = pkgs.python3Packages;
  vscodeSettings = {
    "python.defaultInterpreterPath" = "\${workspaceFolder}/.venv/bin/python";
    "python.terminal.activateEnvInSelectedTerminal" = true;
    "editor.formatOnSave" = true;
    "python.formatting.provider" = "none"; # Let Ruff/Black handle it via LSP
    "python.analysis.typeCheckingMode" = "basic";
  };
  settingsJson = builtins.toJSON vscodeSettings;

  # Zed LSP settings fragment (relative paths, no hardcoded nix-store paths)
  zedSettings = {
    "languages" = {
      "Python" = {
        "format_on_save" = "on";
        "language_servers" = ["pyright"];
      };
    };
    "lsp" = {
      "pyright" = {
        "binary" = {
          "path" = "__PROJECT_DIR__/.zed/lsp/pyright";
        };
      };
    };
  };
  zedFragmentJson = builtins.toJSON zedSettings;
in
pkgs.mkShell {
  buildInputs = [
    pythonEnv             # The interpreter

    # Standard tools
    pkgs.poetry
    pkgs.pyright

    # Python-specific tools from the package set
    pythonPkgs.black
    pythonPkgs.isort
    pythonPkgs.flake8
    pythonPkgs.mypy
    pythonPkgs.pip
    pythonPkgs.ruff
  ] ++ extraPackages;

  shellHook = ''
    mkdir -p .vscode
    if [ ! -f .vscode/settings.json ] || [ "$(cat .vscode/settings.json 2>/dev/null)" != '${settingsJson}' ]; then
      echo '${settingsJson}' > .vscode/settings.json
    fi


    if [ ! -d ".venv" ]; then
      python -m venv .venv
    fi
    source .venv/bin/activate
    export PIP_DISABLE_PIP_VERSION_CHECK=1
    export POETRY_VIRTUALENVS_CREATE=false

    echo "🐍 Python Venv is active at ./.venv"

    dep_hash=""
    if [ -f "pyproject.toml" ] || [ -f "poetry.lock" ] || [ -f "requirements.txt" ]; then
      dep_hash=$(cat pyproject.toml poetry.lock requirements.txt 2>/dev/null | sha256sum | cut -d' ' -f1)
    fi

    dep_stamp_file=".venv/.deps.stamp"
    previous_dep_hash=""
    if [ -f "$dep_stamp_file" ]; then
      previous_dep_hash=$(cat "$dep_stamp_file")
    fi

    if [ -n "$dep_hash" ] && [ "$dep_hash" != "$previous_dep_hash" ]; then
      if [ -f "pyproject.toml" ] && [ -f "poetry.lock" ]; then
        echo "📦 Poetry detected. Syncing dependencies..."
        if poetry install; then
          echo "$dep_hash" > "$dep_stamp_file"
        fi
      elif [ -f "pyproject.toml" ]; then
        echo "📦 pyproject.toml detected. Installing with pip..."
        if .venv/bin/pip install .; then
          echo "$dep_hash" > "$dep_stamp_file"
        fi
      elif [ -f "requirements.txt" ]; then
        echo "📄 requirements.txt detected. Installing..."
        if .venv/bin/pip install -r requirements.txt; then
          echo "$dep_hash" > "$dep_stamp_file"
        fi
      fi
    elif [ -n "$dep_hash" ]; then
      echo "✅ Python dependencies unchanged. Skipping install."
    else
      echo "ℹ️ No dependency file found. Skipping auto-install."
    fi
    # Setup Zed LSP wrapper for pyright (NixOS compatible)
    mkdir -p .zed/lsp
    cat > .zed/lsp/pyright << 'PYRIGHT_WRAPPER'
#!/usr/bin/env bash
# Reusable pyright wrapper for Zed on NixOS
# Uses the wrapper's own location to find the project root (two levels up from .zed/lsp/)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "''${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Use direnv to run pyright with the correct environment
exec direnv exec "$PROJECT_DIR" pyright-langserver --stdio 2>/dev/null
PYRIGHT_WRAPPER
    chmod +x .zed/lsp/pyright

    # Write Zed settings fragment for merging
    mkdir -p .zed/lsp-config
    echo '${zedFragmentJson}' > .zed/lsp-config/python.json

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
      echo "⚠️  Node not available. Using Python Zed settings only."
    fi
  '';
  passthru = {
    inherit vscodeSettings zedSettings;
  };
}
