{ pkgs, ... }:
{ extraPackages ? [] }:

let
  # Get the jre from ltex-ls-plus package
  ltexPackage = pkgs.ltex-ls-plus;
  ltexBinPath = "${ltexPackage}/bin";

  # VS Code settings for markdown
  vscodeSettings = {
    "[markdown]" = {
      "editor.formatOnSave" = true;
      "editor.defaultFormatter" = "DavidAnson.vscode-markdownlint";
    };
    "markdownlint.config" = {
      "default" = true;
    };
  };
  settingsJson = builtins.toJSON vscodeSettings;

  # Zed LSP settings fragment (relative paths, no hardcoded nix-store paths)
  zedSettings = {
    "languages" = {
      "Markdown" = {
        "format_on_save" = "on";
        "language_servers" = [ "ltex" ];
      };
    };
    "lsp" = {
      "ltex" = {
        "binary" = {
          "path" = "__PROJECT_DIR__/.zed/lsp/ltex-ls";
        };
      };
    };
  };
  zedFragmentJson = builtins.toJSON zedSettings;
in
pkgs.mkShell {
  buildInputs = with pkgs; [
    ltex-ls-plus
    pkgs.jre21
  ] ++ extraPackages;

  shellHook = ''
    echo "📝 Markdown environment initialized"

    mkdir -p .vscode
    if [ ! -f .vscode/settings.json ] || [ "$(cat .vscode/settings.json 2>/dev/null)" != '${settingsJson}' ]; then
      echo '${settingsJson}' > .vscode/settings.json
    fi

    # Setup Zed LSP wrapper for ltex-ls (NixOS compatible - uses system jre)
    mkdir -p .zed/lsp
    cat > .zed/lsp/ltex-ls << LTEX_WRAPPER
#!/usr/bin/env bash
# ltex-ls wrapper for NixOS - uses system jre instead of bundled JDK
exec "${ltexBinPath}/ltex-ls" "\$@"
LTEX_WRAPPER
    chmod +x .zed/lsp/ltex-ls

    # Write Zed settings fragment for merging
    mkdir -p .zed/lsp-config
    echo '${zedFragmentJson}' > .zed/lsp-config/markdown.json

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
      echo "⚠️  Node not available. Using Markdown Zed settings only."
    fi
  '';

  passthru = {
    inherit vscodeSettings zedSettings;
  };
}
