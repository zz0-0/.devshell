# DevShell Flake: Multi-Language Development Environments

A modular Nix flake providing development environments for multiple programming languages, built around the **NixOS + direnv** workflow: each project folder gets its own isolated toolchain (language servers, formatters, linters, dependency management) with no containers or VMs — the Nix store deduplicates everything.

## ✨ Features

- **Per-Folder Isolation**: `use flake` in a project's `.envrc` activates exactly the toolchain that project needs
- **Editor Integration**: Automatic `.vscode/settings.json` and `.zed/settings.json` generation; LSP servers resolve through the project's direnv environment, so they work regardless of how the editor was launched
- **Automatic Dependency Management**: Detects dependency files and installs/syncs them (poetry/pip, cargo, pub, maven)
- **Sane `TERM` fallback**: Restores `xterm-256color` when the parent environment reports `TERM=dumb`, so Starship and other prompt tools keep working
- **Language-Aware Tools**: Includes language servers, formatters, and linters
- **Project Scaffolding**: `nix flake init -t devshell#<lang>` creates a ready-to-use project
- **Cross-Platform**: Supports x86_64-linux and aarch64-linux

## 🚀 Quick Start

```bash
# 1. Scaffold a project (creates flake.nix + .envrc + .gitignore)
nix flake init -t github:zz0-0/devshell#python

# 2. Enable direnv
direnv allow
```

That's it. Entering the directory now gives you a Python environment with
pyright/ruff, auto-venv, and automatic dependency installation — isolated to
that folder.

### Without Templates

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    devshell.url = "github:zz0-0/devshell";
  };

  outputs = { self, nixpkgs, devshell }: {
    # Supported systems: x86_64-linux, aarch64-linux
    devShells.x86_64-linux.default = devshell.lib.x86_64-linux.python { };
  };
}
```

```bash
echo "use flake" > .envrc && direnv allow
```

Or without direnv: `nix develop` to enter the shell interactively.

## 📦 Supported Languages

| Language | Function | Tools Included |
|----------|----------|----------------|
| **Python** | `devshell.lib.<system>.python` | python3, pip, poetry, ruff, basedpyright |
| **Rust** | `devshell.lib.<system>.rust` | cargo, rustc, rust-analyzer, rustfmt, clippy, lldb |
| **Flutter** | `devshell.lib.<system>.flutter` | flutter, android-sdk, jdk17, gradle, cmake, chromium |
| **LaTeX** | `devshell.lib.<system>.latex` | texlive (scheme-medium + latexextra), texlab, pandoc, ghostscript |
| **Nix** | `devshell.lib.<system>.nix` | nil, nixd, statix, nixfmt, deadnix |
| **Markdown** | `devshell.lib.<system>.markdown` | markdown-oxide |
| **PostgreSQL** | `devshell.lib.<system>.postgresql` | postgresql + start_pg/stop_pg/reset_pg helpers |
| **Java** | `devshell.lib.<system>.java` | jdk25, jdt-language-server, maven, gradle |
| **Video** | `devshell.lib.<system>.video` | ffmpeg, Chromium, Node, Python, uv, media CLI, Whisper, Assimp |

## 🛠️ Language-Specific Features

### Python Environment
- **Auto-venv**: Creates and activates `.venv/`
- **Dependency Detection**: Automatically detects and installs from:
  - `pyproject.toml` + `poetry.lock` → `poetry install`
  - `pyproject.toml` → `pip install -e .`
  - `requirements.txt` → `pip install -r requirements.txt`
- **Hash Tracking**: Only reinstalls when dependencies change

### Rust Environment
- **Cargo Cache**: Runs `cargo fetch` when `Cargo.toml`/`Cargo.lock` changes
- **Formatting**: rustfmt configured for format-on-save

### Flutter Environment
- **Android SDK**: Pre-configured with license auto-acceptance
- **Engine Patch**: NixOS `flutter_tester` executable fix (cached in `/tmp`, keyed by store hash)
- **Freezed Support**: Auto-runs `build_runner` when freezed is detected
- **Desktop Development**: Linux desktop dependencies (GTK, X11, Wayland)

### LaTeX Environment
- **VS Code Integration**: latex-workshop configured with absolute store paths
- **Zed Integration**: texlab build-on-save with `-outdir=build`; PDF preview
  via evince (the zed-latex extension auto-configures its synctex wrapper;
  the shell provides python3 + gi/dbus + evince for it)
- **Build Automation**: latexmk with synctex, `-outdir=build`

### PostgreSQL Environment
- **Project-Local Data**: data lives in `.postgres/` inside the project
- **Helpers**: `start_pg`, `stop_pg`, `reset_pg` commands added to PATH

### Video Environment
- **Toolchain**: ffmpeg, Chromium, Node, Python, uv, media CLI, Whisper, Assimp
- **Browser**: Nix Chromium is exported as `HYPERFRAMES_BROWSER_PATH`, `REMOTION_BROWSER_EXECUTABLE`, and `CHROME_PATH`
- **No auto-venv**: this shell does not create `.venv`; use `uv` when a project needs Python packages
- **GUI software**: Kdenlive, OBS, GIMP, Inkscape, Audacity, Aegisub, MeshLab, and Blender stay in the NixOS/Home Manager configuration, not in the project shell
- **Check**: `./scripts/check-video.sh` evaluates the video shell without pulling the LaTeX/Tex Live check

## 🔧 Customizing Environments

```nix
# Add extra packages to any environment
devShells.x86_64-linux.default = devshell.lib.x86_64-linux.python {
  extraPackages = [ pkgs.redis ];
};

# Flutter with emulator support
devShells.x86_64-linux.default = devshell.lib.x86_64-linux.flutter {
  withEmulator = true;
};

# Choose a different Python or JDK
devShells.x86_64-linux.default = devshell.lib.x86_64-linux.python {
  python = pkgs.python312;
};
devShells.x86_64-linux.default = devshell.lib.x86_64-linux.java {
  jdk = pkgs.jdk21;
};
```

## 🏗️ Project Structure

```
.devshell/
├── flake.nix                # Main flake configuration (lib, formatter, checks, templates)
├── languages/
│   ├── common.nix           # Shared helpers (LSP wrappers, settings writers)
│   ├── python.nix           # Python development environment
│   ├── rust.nix             # Rust development environment
│   ├── flutter.nix          # Flutter development environment
│   ├── latex.nix            # LaTeX development environment
│   ├── nix.nix              # Nix development tools
│   ├── markdown.nix         # Markdown tooling
│   ├── postgresql.nix       # PostgreSQL development environment
│   └── java.nix             # Java development environment
└── templates/               # `nix flake init -t` scaffolds (one dir per language)
```

## 🔄 Auto-Generated Files

When you enter a devshell, it automatically creates (project-local, gitignored):
- `.vscode/settings.json` – VS Code configuration (language server paths, formatters)
- `.zed/settings.json` – Zed configuration
- `.zed/lsp/` – LSP wrapper scripts resolving through `direnv exec`
- `.venv/` – Python virtual environment (Python shells)
- `.dart_tool/` – Flutter cache and stamp files
- `.postgres/` – PostgreSQL data directory (PostgreSQL shells)
- `.bin/` – Symlinks to Nix tools (Nix shell)
- `target/` – Rust build directory

All files are regenerated idempotently: nothing is wiped on updates, and files
are only rewritten when their content actually changed.

## 🧠 How It Works

- **direnv + `use flake`** is the core mechanism: entering a project directory loads its `devShells.default`, so `PATH` and environment variables come from the Nix store and are scoped to that folder.
- **LSP wrappers** (`languages/common.nix`) resolve the project root from their own location and run the language server via `direnv exec`, so Zed/VS Code always use the exact toolchain of the project — even when launched from outside the shell.
- **Hash stamps** skip expensive operations (venv install, `cargo fetch`, `flutter pub get`, maven fetch) until the dependency files actually change.

### Combining Languages

Shells can be combined for multi-language projects; each shell writes a Zed
settings *fragment* (`.zed/lsp-config/<lang>.json`) and they are deep-merged
into `.zed/settings.json`:

```nix
devShells.${system}.default = pkgs.mkShellNoCC {
  buildInputs = nixShell.buildInputs ++ markdownShell.buildInputs;
  shellHook = ''
    ${nixShell.shellHook}
    ${markdownShell.shellHook}
  '';
};
```

Video can be combined the same way:

```nix
let
  pythonShell = devshell.lib.${system}.python { };
  rustShell = devshell.lib.${system}.rust { };
  videoShell = devshell.lib.${system}.video { };
in
devShells.${system}.default = pkgs.mkShellNoCC {
  buildInputs = pythonShell.buildInputs ++ rustShell.buildInputs ++ videoShell.buildInputs;
  shellHook = ''
    ${pythonShell.shellHook}
    ${rustShell.shellHook}
    ${videoShell.shellHook}
  '';
};
```

Note: `.vscode/settings.json` can only hold one language's configuration — the
last shell in the hook wins there. Zed settings merge correctly for all shells.

## 🔒 Security Notes

- **Android Licenses**: The Flutter environment attempts to accept Android SDK licenses automatically. If this fails, run `flutter doctor --android-licenses` manually.
- **Nix Config**: This flake sets `allowUnfree = true` and `android_sdk.accept_license = true` for its own nixpkgs instance; no global config changes required.

## 🤝 Contributing

To add a new language:
1. Create a new file in `languages/` following the existing pattern (uses helpers from `common.nix`)
2. Add it to the `lib` outputs in `flake.nix`
3. Add a template directory under `templates/`

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with [Nix](https://nixos.org/) and [Nix Flakes](https://nixos.wiki/wiki/Flakes)
