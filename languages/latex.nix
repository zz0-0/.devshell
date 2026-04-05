{ pkgs, ... }:
{ extraPackages ? [] }:

let
  texEnv = pkgs.texlive.combine {
    inherit (pkgs.texlive)
      scheme-medium
      collection-latexextra
      collection-fontsrecommended
      latexmk
      biblatex
      biber;
  };

  # Calculate the absolute path to the bin directory in the Nix store
  texBinPath = "${texEnv}/bin";

  vscodeSettings = {
    "latex-workshop.view.pdf.viewer" = "tab";
    "latex-workshop.latex.autoBuild.run" = "onSave";
    "latex-workshop.latex.recipe.default" = "latexmk";

    # This is the magic part: We tell the extension exactly where to look
    "latex-workshop.latex.tools" = [
      {
        "name" = "latexmk";
        "command" = "${texBinPath}/latexmk"; # Absolute path
        "args" = [
          "-shell-escape"
          "-synctex=1"
          "-interaction=nonstopmode"
          "-file-line-error"
          "-pdf"
          "-outdir=build"
          "%DOC%"
        ];
        "env" = {
          "PATH" = "${texBinPath}:${pkgs.coreutils}/bin"; # Ensure it has basics
        };
      }
    ];
  };
in
pkgs.mkShell {
  buildInputs = [
    texEnv
    pkgs.texlab
    pkgs.pandoc
    pkgs.ghostscript
  ] ++ extraPackages;

  shellHook = ''
    echo "📄 LaTeX environment initialized"
    mkdir -p .vscode
    if [ ! -f .vscode/settings.json ] || [ "$(cat .vscode/settings.json 2>/dev/null)" != '${builtins.toJSON vscodeSettings}' ]; then
      echo '${builtins.toJSON vscodeSettings}' > .vscode/settings.json
    fi
  '';

  # Zed LSP settings with direct nix-store paths (merged by combined shell)
  zedSettings = {
    "lsp" = {
      "texlab" = {
        "binary" = {
          "path" = "${pkgs.texlab}/bin/texlab";
          "path_lookup" = "true";
        };
      };
    };
  };

  passthru = {
    inherit vscodeSettings zedSettings;
  };
}
