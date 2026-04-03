
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
  '';
  passthru = {
    inherit vscodeSettings;
  };
}
