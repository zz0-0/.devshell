{ pkgs, ... }:
{ extraPackages ? [] }:

let
  # VS Code settings
  vscodeSettings = {
    "rust-analyzer.server.path" = "rust-analyzer";
    "rust-analyzer.cargo.buildScripts.enable" = true;
    "rust-analyzer.procMacro.enable" = true;
    "editor.formatOnSave" = true;
    "editor.defaultFormatter" = "rust-lang.rust-analyzer";
  };
  settingsJson = builtins.toJSON vscodeSettings;

  # Zed LSP settings fragment (relative paths, no hardcoded nix-store paths)
  zedSettings = {
    "languages" = {
      "Rust" = {
        "format_on_save" = "on";
        "language_servers" = ["rust-analyzer"];
      };
    };
    "lsp" = {
      "rust-analyzer" = {
        "binary" = {
          "path" = "\${PWD}/.zed/lsp/rust-analyzer";
        };
        "initialization_options" = {
          "cargo" = {
            "buildScripts" = {
              "enable" = true;
            };
          };
          "procMacro" = {
            "enable" = true;
          };
        };
      };
    };
  };
  zedFragmentJson = builtins.toJSON zedSettings;
in
pkgs.mkShell {
  buildInputs = with pkgs; [
    # Toolchain
    cargo
    rustc
    rustup
    rust-analyzer
    rustfmt
    clippy
    lldb
  ] ++ extraPackages;

  shellHook = ''
    echo "🦀 Rust dev environment loaded"

    # Ensure pkg-config can find libraries
    export PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig"

    # Setup VS Code
    mkdir -p .vscode
    if [ ! -f .vscode/settings.json ] || [ "$(cat .vscode/settings.json 2>/dev/null)" != '${settingsJson}' ]; then
      echo '${settingsJson}' > .vscode/settings.json
    fi

    # Setup Zed LSP wrapper for rust-analyzer (NixOS compatible)
    mkdir -p .zed/lsp
    cat > .zed/lsp/rust-analyzer << 'RUST_ANALYZER_WRAPPER'
#!/usr/bin/env bash
# Reusable rust-analyzer wrapper for Zed on NixOS
# Finds the nearest .envrc and uses direnv to run the correct rust-analyzer binary
set -euo pipefail
dir="$PWD"
while [[ "$dir" != "/" ]]; do
  if [[ -f "$dir/.envrc" ]]; then
    exec direnv exec "$dir" bash -c '
      for d in $(echo "$PATH" | tr ":" "\n"); do
        # Skip rustup directories and .zed/lsp wrapper directories
        if [[ "$d" == *rustup* ]] || [[ "$d" == *".zed/lsp"* ]]; then
          continue
        fi
        if [[ -f "$d/rust-analyzer" ]] && [[ ! -L "$d/rust-analyzer" || "$(readlink -f "$d/rust-analyzer")" != *rustup* ]]; then
          exec "$d/rust-analyzer" "$@"
        fi
      done
      echo "Error: rust-analyzer not found in direnv environment" >&2
      exit 1
    ' -- "$@"
  fi
  dir="$(dirname "$dir")"
done
exec rust-analyzer "$@"
RUST_ANALYZER_WRAPPER
    chmod +x .zed/lsp/rust-analyzer

    # Write Zed settings fragment for merging
    mkdir -p .zed/lsp-config
    echo '${zedFragmentJson}' > .zed/lsp-config/rust.json

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
      echo "⚠️  Node not available. Using Rust Zed settings only."
    fi

    rust_dep_hash=""
    if [ -f "Cargo.toml" ] || [ -f "Cargo.lock" ]; then
      rust_dep_hash=$(cat Cargo.toml Cargo.lock 2>/dev/null | sha256sum | cut -d' ' -f1)
    fi

    rust_dep_stamp_file="target/.deps.stamp"
    rust_previous_dep_hash=""
    if [ -f "$rust_dep_stamp_file" ]; then
      rust_previous_dep_hash=$(cat "$rust_dep_stamp_file")
    fi

    if [ -n "$rust_dep_hash" ] && [ "$rust_dep_hash" != "$rust_previous_dep_hash" ]; then
      echo "📦 Rust manifest changed. Fetching crates..."
      if [ -f "Cargo.lock" ]; then
        if cargo fetch --locked; then
          mkdir -p target
          echo "$rust_dep_hash" > "$rust_dep_stamp_file"
        fi
      else
        if cargo fetch; then
          mkdir -p target
          echo "$rust_dep_hash" > "$rust_dep_stamp_file"
        fi
      fi
    elif [ -n "$rust_dep_hash" ]; then
      echo "✅ Rust dependencies unchanged. Skipping cargo fetch."
    fi

    echo "✅ Rust toolchain ready. Use 'cargo build' to start."
  '';
  passthru = {
    inherit vscodeSettings zedSettings;
  };
}
