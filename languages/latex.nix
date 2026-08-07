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

  texEnv = pkgs.texlive.withPackages (
    ps: with ps; [
      scheme-medium
      collection-latexextra
      collection-fontsrecommended
      latexmk
      biblatex
      biber
    ]
  );

  # Absolute path to the bin directory in the Nix store (VS Code is not
  # direnv-aware, so latex-workshop gets explicit paths)
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
  settingsJson = builtins.toJSON vscodeSettings;

  # Zed LSP settings fragment
  zedSettings = {
    "languages" = {
      "LaTeX" = {
        "format_on_save" = "on";
        "language_servers" = [ "texlab" ];
      };
    };
    "lsp" = {
      "texlab" = {
        "binary" = {
          "path" = "__PROJECT_DIR__/.zed/lsp/texlab";
        };
        "initialization_options" = {
          "texlab" = {
            "build" = {
              "args" = [
                "-synctex=1"
                "-pdf"
                "-interaction=nonstopmode"
                "-outdir=build"
                "%f"
              ];
              "executable" = "latexmk";
              "forwardSearchAfter" = true;
              "onSave" = true;
            };
            "forwardSearch" = {
              "args" = [
                "--synctex-forward"
                "%l:1:%f"
                "-x"
                "zed %%{input}:%%{line}"
                "%p"
              ];
              "executable" = "evince";
            };
          };
        };
      };
    };
  };
  zedFragmentJson = builtins.toJSON zedSettings;
in
common.mkShell {
  buildInputs = [
    texEnv
    pkgs.texlab
    pkgs.pandoc
    pkgs.ghostscript
  ]
  ++ extraPackages;

  shellHook = ''
    ${writeVscodeSettings settingsJson}
    ${writeZedFragment "latex" zedFragmentJson}
    ${writeLspWrapper {
      name = "texlab";
      command = "texlab";
    }}
    ${mergeZedSettings}

    echo "📄 LaTeX environment initialized"
  '';

  passthru = {
    inherit vscodeSettings zedSettings;
  };
}
