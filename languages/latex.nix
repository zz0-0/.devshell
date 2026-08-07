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

  # Zed LSP settings fragment.
  #
  # Build config goes under `settings` (texlab v5 ignores initialization_options),
  # with -outdir=build so artifacts land in build/. forwardSearch is intentionally
  # NOT set: the zed-latex extension detects evince on PATH and injects its own
  # evince preset (python synctex wrapper) at runtime.
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
        "settings" = {
          "texlab" = {
            "build" = {
              "executable" = "latexmk";
              "args" = [
                "-synctex=1"
                "-pdf"
                "-interaction=nonstopmode"
                "-outdir=build"
                "%f"
              ];
              "onSave" = true;
              "forwardSearchAfter" = true;
              "auxDirectory" = "build";
              "logDirectory" = "build";
              "pdfDirectory" = "build";
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
    # PDF preview: the zed-latex extension drives evince through a python
    # synctex wrapper (dbus + gi), and texlab spawns `python3` for it.
    pkgs.evince
    pkgs.python3
    pkgs.python3Packages.pygobject3
    pkgs.python3Packages.dbus-python
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

    # Let gi (PyGObject) find the GLib typelib and its shared libraries, so the
    # evince synctex wrapper (spawned by texlab) can import gi/dbus.
    export GI_TYPELIB_PATH="${pkgs.glib}/lib/girepository-1.0"
    export LD_LIBRARY_PATH="${pkgs.glib}/lib:${pkgs.libffi}/lib"

    echo "📄 LaTeX environment initialized"
  '';

  passthru = {
    inherit vscodeSettings zedSettings;
  };
}
