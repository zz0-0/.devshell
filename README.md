# DevShell Flake: Multi-Language Development Environments

A modular Nix flake providing development environments for multiple programming languages with automatic tooling and VS Code integration.

## ✨ Features

- **Unified Development Environments**: Consistent environments across languages
- **VS Code Integration**: Automatic `.vscode/settings.json` generation
- **Automatic Dependency Management**: Detects dependency files and installs packages
- **Language-Aware Tools**: Includes language servers, formatters, and linters
- **Modular Design**: Combine languages or use standalone environments
- **Cross-Platform**: Supports x86_64-linux and aarch64-linux

## 📦 Supported Languages

### Combined Environments (with Nix + Markdown)
Each combined environment includes:
- Language-specific tooling
- Nix development tools (nixfmt, nil, statix, deadnix)
- Markdown tooling (ltex-ls, markdown-oxide, rumdl)

| Language | Tools Included | Combined Function |
|----------|----------------|-------------------|
| **LaTeX** | texlive (scheme-medium), texlab, pandoc | `devshell.lib.<system>.latex` |
| **Python** | python3, poetry, pyright, black, ruff, mypy | `devshell.lib.<system>.python` |
| **Rust** | cargo, rustc, rust-analyzer, rustfmt, clippy | `devshell.lib.<system>.rust` |
| **Flutter** | flutter, android-sdk, jdk17, gradle, cmake | `devshell.lib.<system>.flutter` |

### Standalone Environments
For advanced use cases where you want more control:
| Language | Function | Description |
|----------|----------|-------------|
| Nix | `devshell.lib.<system>.nix` | Nix development tools only |
| Markdown | `devshell.lib.<system>.markdown` | Markdown tooling only |
| Language-only | `devshell.lib.<system>.<lang>Standalone` | Language without Nix+Markdown |

## 🚀 Quick Start

### 1. Add to Your Project Flake

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    devshell.url = "github:zz0-0/devshell";
  };

  outputs = { self, nixpkgs, devshell, ... }: let
    # Supported systems: x86_64-linux, aarch64-linux
    system = "x86_64-linux";
  in {
    devShells.${system} = {
      # Create language-specific development shells
      # User Python just as an example
      python = devshell.lib.${system}.python { };
    };
  };
}
```

### 2. Enter a DevShell

```bash
# Enter a specific language environment
nix develop .#python

# Or using direnv for automatic environment activation
echo "use flake .#python" > .envrc && direnv allow
```

### 3. Use with VS Code

VS Code will automatically:
- Use the correct language server from the Nix environment
- Apply formatting on save
- Use project-specific settings from `.vscode/settings.json`

## 🛠️ Language-Specific Features

### Python Environment
- **Auto-venv**: Creates and activates virtual environment
- **Dependency Detection**: Automatically detects and installs from:
  - `pyproject.toml` + `poetry.lock` → `poetry install`
  - `pyproject.toml` → `pip install .`
  - `requirements.txt` → `pip install -r requirements.txt`
- **Hash Tracking**: Only reinstalls when dependencies change
- **Tools**: poetry, pyright, black, isort, flake8, mypy, ruff

### Rust Environment
- **Cargo Cache**: Automatically runs `cargo fetch` when `Cargo.toml` changes
- **Toolchain**: Full Rust toolchain with rust-analyzer integration
- **Formatting**: rustfmt configured for format-on-save
- **Tools**: cargo, rustc, rust-analyzer, rustfmt, clippy

### Flutter Environment
- **Android SDK**: Pre-configured Android development environment
- **License Management**: Automatically attempts to accept Android licenses
- **Freezed Support**: Auto-runs `build_runner` when freezed is detected
- **Desktop Development**: Linux desktop dependencies (GTK, X11, Wayland)
- **Tools**: flutter, android-sdk, jdk17, gradle, cmake, ninja

### LaTeX Environment
- **VS Code Integration**: Configures latex-workshop with absolute paths
- **Build Automation**: Uses latexmk with automatic synctex generation
- **Tooling**: Full texlive scheme-medium with biber, biblatex support
- **Tools**: texlive, texlab, pandoc, ghostscript

### Nix Environment
- **Formatter Integration**: Creates symlinks for nixfmt accessible to VS Code
- **Language Server**: Configures nil as the Nix language server
- **Tooling**: Complete Nix development toolchain
- **Tools**: nil, nixd, statix, nixfmt, deadnix

## 🔧 Advanced Usage

### Customizing Environments

```nix
# Add extra packages to any environment
python = devshell.lib.python {
  extraPackages = [ pkgs.redis pkgs.postgresql ];
};

# Flutter with emulator support
flutter = devshell.lib.flutter {
  withEmulator = true;
  extraPackages = [ pkgs.emacs ];
};
```

### Creating Combined Shells Manually

```nix
# Combine multiple language shells
combined = devshell.lib.combineShells [
  (devshell.lib.pythonStandalone { })
  (devshell.lib.rustStandalone { })
  (devshell.lib.nix { })
];
```

### Using the `withNixAndMarkdown` Helper

```nix
# Add Nix+Markdown to any custom shell function
customShell = devshell.lib.withNixAndMarkdown (args: pkgs.mkShell {
  buildInputs = [ pkgs.nodejs pkgs.yarn ];
  shellHook = "echo 'Node.js environment'";
}) { };
```

## 🏗️ Project Structure

```
.devshell/
├── flake.nix              # Main flake configuration
├── languages/             # Language-specific modules
│   ├── latex.nix         # LaTeX development environment
│   ├── python.nix        # Python development environment  
│   ├── rust.nix          # Rust development environment
│   ├── flutter.nix       # Flutter development environment
│   ├── nix.nix           # Nix development tools
│   └── markdown.nix      # Markdown tooling
└── README.md             # This file
```

## 🔄 Auto-Generated Files

When you enter a devshell, it automatically creates:
- `.vscode/settings.json` – VS Code configuration
- `.venv/` – Python virtual environment (for Python shells)
- `.dart_tool/` – Flutter cache and stamp files
- `.bin/` – Symlinks to Nix tools (for Nix shell)
- `target/` – Rust build directory

## 📝 VS Code Integration Details

The devshell automatically generates `.vscode/settings.json` with:
- Language server paths from the Nix store
- Formatter configurations
- Save/format policies
- Project-specific tool paths

This ensures VS Code uses the exact same tools as your shell environment.

## 🔒 Security Notes

- **Android Licenses**: The Flutter environment attempts to accept Android SDK licenses automatically. If this fails, run `flutter doctor --android-licenses` manually.
- **Nix Config**: Requires `allowUnfree = true` and `android_sdk.accept_license = true` in your Nix configuration for full functionality.

## 🤝 Contributing

To add a new language:
1. Create a new file in `languages/` directory
2. Follow the pattern: export both standalone and combined versions
3. Include VS Code settings generation
4. Add to the `lib` outputs in `flake.nix`

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with [Nix](https://nixos.org/) and [Nix Flakes](https://nixos.wiki/wiki/Flakes)
