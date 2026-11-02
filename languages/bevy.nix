{ pkgs, ... }:

{
  extraPackages ? [ ],
}:

let
  rust = import ./rust.nix { inherit pkgs; };

  # Bevy's default Linux feature set dynamically loads these at runtime, and
  # several of them are also needed at build time (pkg-config / bindings).
  runtimeLibs = with pkgs; [
    alsa-lib
    udev
    libGL
    vulkan-loader
    mesa
    libx11
    libxcursor
    libxrandr
    libxi
    libxext
    libxrender
    libxinerama
    libxxf86vm
    libxcb
    libxkbcommon
    wayland
    fontconfig
    freetype
  ];

  buildTools = with pkgs; [
    pkg-config
    clang
    lld
    mold
    cmake
    python3
    wayland-protocols
    cargo-nextest
  ];

  base = rust {
    extraPackages = runtimeLibs ++ buildTools ++ extraPackages;
  };
in
base.overrideAttrs (old: {
  shellHook = old.shellHook + ''
    # Bevy loads graphics, audio and input libraries dynamically. Nix keeps
    # them in the store, so expose them for the lifetime of this shell.
    # The NixOS GPU driver path comes first so the real driver wins over Mesa.
    export LD_LIBRARY_PATH="/run/opengl-driver/lib:${pkgs.lib.makeLibraryPath runtimeLibs}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

    # On NixOS the active GPU's Vulkan ICD lives outside the Nix store.
    if [ -z "''${VK_ICD_FILENAMES-}" ] && [ -d /run/opengl-driver/share/vulkan/icd.d ]; then
      export VK_ICD_FILENAMES="$(find /run/opengl-driver/share/vulkan/icd.d -name '*.json' -print | paste -sd: -)"
    fi

    echo "🎮 Bevy dev environment loaded"
    echo "   cargo run     # windowed game"
    echo "   cargo test    # headless tests"
  '';
})
