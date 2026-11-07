# Language-specific features

> 对应：`languages/*.nix`、`templates/*/`

## Python Environment
- **Auto-venv**: Creates and activates `.venv/`
- **Dependency Detection**: Automatically detects and installs from:
  - `pyproject.toml` + `poetry.lock` → `poetry install`
  - `pyproject.toml` → `pip install -e .`
  - `requirements.txt` → `pip install -r requirements.txt`
- **Hash Tracking**: Only reinstalls when dependencies change

## Rust Environment
- **Cargo Cache**: Runs `cargo fetch` when `Cargo.toml`/`Cargo.lock` changes
- **Formatting**: rustfmt configured for format-on-save

## Bevy Environment
- **Everything in Rust**: inherits the Rust shell (cargo, rust-analyzer, rustfmt, clippy, lldb)
- **Linux runtime**: exposes ALSA, udev, Vulkan and X11/Wayland libraries on `LD_LIBRARY_PATH`
- **NixOS GPU drivers**: prepends `/run/opengl-driver/lib` and points `VK_ICD_FILENAMES` at the active Vulkan ICD when present
- **Build tools**: pkg-config, clang, lld, mold, cmake, wayland-protocols, cargo-nextest
- **Scope**: a separate shell, so plain Rust projects keep their lean toolchain

## Flutter Environment
- **Android SDK**: Pre-configured with license auto-acceptance
- **Engine Patch**: NixOS `flutter_tester` executable fix (cached in `/tmp`, keyed by store hash)
- **Freezed Support**: Auto-runs `build_runner` when freezed is detected
- **Desktop Development**: Linux desktop dependencies (GTK, X11, Wayland)

## LaTeX Environment
- **VS Code Integration**: latex-workshop configured with absolute store paths
- **Zed Integration**: texlab build-on-save with `-outdir=build`; PDF preview
  via evince (the zed-latex extension auto-configures its synctex wrapper;
  the shell provides python3 + gi/dbus + evince for it)
- **Build Automation**: latexmk with synctex, `-outdir=build`

## PostgreSQL Environment
- **Project-Local Data**: data lives in `.postgres/` inside the project
- **Helpers**: `start_pg`, `stop_pg`, `reset_pg` commands added to PATH

## Video Environment
- **Toolchain**: ffmpeg, Chromium, Node, Python, uv, media CLI, Whisper, Assimp
- **Browser**: Nix Chromium is exported as `HYPERFRAMES_BROWSER_PATH`, `REMOTION_BROWSER_EXECUTABLE`, and `CHROME_PATH`
- **No auto-venv**: this shell does not create `.venv`; use `uv` when a project needs Python packages
- **GUI software**: Kdenlive, OBS, GIMP, Inkscape, Audacity, Aegisub, MeshLab, and Blender stay in the NixOS/Home Manager configuration, not in the project shell
- **Check**: `./scripts/check-video.sh` evaluates the video shell without pulling the LaTeX/Tex Live check

