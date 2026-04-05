{ pkgs, ... }:
{ extraPackages ? [] }:

let
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

  # Zed LSP settings (binary path resolved from direnv-provided PATH)
  zedSettings = {
    "lsp" = {
      "ltex" = {};
    };
    "languages" = {
      "Markdown" = {
        "format_on_save" = "on";
      };
    };
  };
in
pkgs.mkShell {
  buildInputs = with pkgs; [
    ltex-ls-plus
  ] ++ extraPackages;

  shellHook = ''
    echo "📝 Markdown environment initialized"

    mkdir -p .vscode
    if [ ! -f .vscode/settings.json ] || [ "$(cat .vscode/settings.json 2>/dev/null)" != '${settingsJson}' ]; then
      echo '${settingsJson}' > .vscode/settings.json
    fi
  '';

  passthru = {
    inherit vscodeSettings zedSettings;
  };
}
