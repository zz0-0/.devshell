{ pkgs, ... }:

{
  extraPackages ? [ ],
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

  # Zed LSP settings fragment
  zedSettings = {
    "languages" = {
      "Markdown" = {
        "format_on_save" = "on";
        "language_servers" = [ "markdown-oxide" ];
      };
    };
    "lsp" = {
      "markdown-oxide" = {
        "binary" = {
          "path" = "__PROJECT_DIR__/.zed/lsp/markdown-oxide";
          "arguments" = [ ];
        };
      };
    };
  };
  zedFragmentJson = builtins.toJSON zedSettings;
in
common.mkShell {
  buildInputs =
    with pkgs;
    [
      markdown-oxide
    ]
    ++ extraPackages;

  shellHook = ''
    ${writeVscodeSettings settingsJson}
    ${writeZedFragment "markdown" zedFragmentJson}
    ${writeLspWrapper {
      name = "markdown-oxide";
      command = "markdown-oxide";
    }}
    ${mergeZedSettings}

    echo "📝 Markdown environment initialized"
  '';

  passthru = {
    inherit vscodeSettings zedSettings;
  };
}
