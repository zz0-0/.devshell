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
in
pkgs.mkShell {
  buildInputs = with pkgs; [
    ltex-ls-plus
    markdown-oxide
    rumdl
  ] ++ extraPackages;

  shellHook = ''
    echo "📝 Markdown environment initialized"

    mkdir -p .vscode
    if [ ! -f .vscode/settings.json ] || [ "$(cat .vscode/settings.json 2>/dev/null)" != '${settingsJson}' ]; then
      echo '${settingsJson}' > .vscode/settings.json
    fi
  '';

  passthru = {
    inherit vscodeSettings;
  };
}
