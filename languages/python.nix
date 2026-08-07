{ pkgs, ... }:

{
  extraPackages ? [ ],
  python ? pkgs.python3,
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
        "language_servers" = [
          "ruff"
          "basedpyright"
        ];
        "code_actions_on_format" = {
          "source.organizeImports.ruff" = true;
        };
        "formatter" = {
          "language_server" = {
            "name" = "ruff";
          };
        };
      };
    };
    "lsp" = {
      "basedpyright" = {
        "binary" = {
          "path" = "__PROJECT_DIR__/.zed/lsp/basedpyright";
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
common.mkShell {
  buildInputs = [
    pythonEnv
    pythonPkgs.pip
    pythonPkgs.ruff
    pkgs.basedpyright
    pkgs.poetry
  ]
  ++ extraPackages;

  shellHook = ''
    ${writeVscodeSettings settingsJson}
    ${writeZedFragment "python" zedFragmentJson}
    ${writeLspWrapper {
      name = "basedpyright";
      command = "basedpyright-langserver --stdio";
    }}
    ${writeLspWrapper {
      name = "ruff";
      command = "ruff server";
    }}
    ${mergeZedSettings}

    if [ ! -d ".venv" ]; then
      python -m venv .venv
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
        if poetry install; then
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
  '';

  passthru = {
    inherit vscodeSettings zedSettings;
  };
}
