{ pkgs, ... }:
{ extraPackages ? [ ], python ? pkgs.python3 }:

let
  # Use bare python interpreter - pip bootstrapped via ensurepip in shellHook
  pythonEnv = python;
  pythonPkgs = python.pkgs;

  vscodeSettings = {
    "python.defaultInterpreterPath" = "\${workspaceFolder}/.venv/bin/python";
    "python.terminal.activateEnvInSelectedTerminal" = true;
    "editor.formatOnSave" = true;
    "python.formatting.provider" = "none";
    "python.analysis.typeCheckingMode" = "basic";
  };
  settingsJson = builtins.toJSON vscodeSettings;

  zedSettings = {
    "languages" = {
      "Python" = {
        "format_on_save" = "on";
        "language_servers" = ["ruff" "pyright"];
        "code_actions_on_format" = {
          "source.organizeImports.ruff" = true;
        };
        "formatter" = {
          "language_server" = { "name" = "ruff"; };
        };
      };
    };
    "lsp" = {
      "pyright" = {
        "binary" = {
          "path" = "__PROJECT_DIR__/.zed/lsp/pyright";
        };
      };
      "ruff" = {
        "binary" = {
          "path" = "__PROJECT_DIR__/.zed/lsp/ruff";
        };
      };
    };
  };
  zedFragmentJson = builtins.toJSON zedSettings;
in
pkgs.mkShell {
  buildInputs = [
    pythonEnv
    pythonPkgs.ruff
    pkgs.pyright
  ] ++ extraPackages;

  shellHook = ''
    mkdir -p .vscode
    if [ ! -f ".vscode/settings.json" ] || [ "$(cat .vscode/settings.json 2>/dev/null)" != '${settingsJson}' ]; then
      echo '${settingsJson}' > .vscode/settings.json
    fi

    if [ ! -d ".venv" ]; then
      python -m venv .venv
      python -m ensurepip
    fi
    source .venv/bin/activate
    export PIP_DISABLE_PIP_VERSION_CHECK=1
    if [ -f "pip.conf" ]; then
      export PIP_CONFIG_FILE="$PWD/pip.conf"
    fi

    echo "🐍 Python venv is active at ./.venv"

    # Auto-install from project dependency files
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
        if pip install poetry && poetry install; then
          echo "$dep_hash" > "$dep_stamp_file"
        fi
      elif [ -f "pyproject.toml" ]; then
        echo "📦 pyproject.toml detected. Installing with pip..."
        if pip install -e .; then
          echo "$dep_hash" > "$dep_stamp_file"
        fi
      elif [ -f "requirements.txt" ]; then
        echo "📄 requirements.txt detected. Installing..."
        if pip install -r requirements.txt; then
          echo "$dep_hash" > "$dep_stamp_file"
        fi
      fi
    elif [ -n "$dep_hash" ]; then
      echo "✅ Python dependencies unchanged. Skipping install."
    else
      echo "ℹ️ No dependency file found. Skipping auto-install."
    fi

    # Zed LSP wrappers
    mkdir -p .zed/lsp
    cat > .zed/lsp/pyright << 'PYRIGHT_WRAPPER'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "''${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
exec direnv exec "$PROJECT_DIR" pyright-langserver --stdio 2>/dev/null
PYRIGHT_WRAPPER
    chmod +x .zed/lsp/pyright

    cat > .zed/lsp/ruff << 'RUFF_WRAPPER'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "''${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
exec direnv exec "$PROJECT_DIR" ruff server -- 2>/dev/null
RUFF_WRAPPER
    chmod +x .zed/lsp/ruff

    mkdir -p .zed/lsp-config
    echo '${zedFragmentJson}' > .zed/lsp-config/python.json

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
              } catch (e) {}
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
        const projectDir = process.env.PWD || process.cwd();
        const settingsStr = JSON.stringify(merged, null, 2).replace(/__PROJECT_DIR__/g, projectDir);
        fs.writeFileSync('.zed/settings.json', settingsStr + '\n');
      "
    else
      echo '${zedFragmentJson}' | sed "s|__PROJECT_DIR__|$PWD|g" > .zed/settings.json
    fi
  '';

  passthru = {
    inherit vscodeSettings zedSettings;
  };
}
