{ pkgs, ... }:
{ extraPackages ? [] }:

let
  # VS Code settings to ensure it uses the tools from the Nix shell
  vscodeSettings = {
    "rust-analyzer.server.path" = "rust-analyzer";
    "rust-analyzer.cargo.buildScripts.enable" = true;
    "rust-analyzer.procMacro.enable" = true;
    "editor.formatOnSave" = true;
    "editor.defaultFormatter" = "rust-lang.rust-analyzer";
  };
  settingsJson = builtins.toJSON vscodeSettings;

  # Zed LSP settings (binary path resolved from direnv-provided PATH)
  zedSettings = {
    "lsp" = {
      "rust-analyzer" = {};
    };
  };
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

  # Environment variables for compilation
  shellHook = ''
    echo "🦀 Rust dev environment loaded"

    # Ensure pkg-config can find libraries
    export PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig"

    # Setup VS Code
    mkdir -p .vscode
    if [ ! -f .vscode/settings.json ] || [ "$(cat .vscode/settings.json 2>/dev/null)" != '${settingsJson}' ]; then
      echo '${settingsJson}' > .vscode/settings.json
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
