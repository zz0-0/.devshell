{ pkgs, ... }:
{ extraPackages ? [], withEmulator ? false }:

let
  lib = pkgs.lib;

  # Note: Requires config.android_sdk.accept_license = true; to be set in your
  # top-level nixpkgs configuration (e.g., in flake.nix or ~/.config/nixpkgs/config.nix)
  androidComposition = pkgs.androidenv.composeAndroidPackages {
    buildToolsVersions = [ "36.0.0" "28.0.3" ];
    platformVersions   = [ "36" "28" ];
    abiVersions =
      [ "armeabi-v7a" "arm64-v8a" ]
      ++ lib.optional withEmulator "x86_64";

    includeEmulator     = withEmulator;
    includeSystemImages = withEmulator;
  };

  androidSdk = androidComposition.androidsdk;

  vscodeSettings = {
    "dart.flutterSdkPath" = ".flutter-sdk";
    "dart.sdkPath" = ".flutter-sdk/bin/cache/dart-sdk";
    "flutter.sdkPath" = ".flutter-sdk";
  };
  settingsJson = builtins.toJSON vscodeSettings;

  # Zed LSP settings fragment (relative paths, no hardcoded nix-store paths)
  zedSettings = {
    "languages" = {
      "Dart" = {
        "format_on_save" = "on";
        "language_servers" = ["dart"];
      };
    };
    "lsp" = {
      "dart" = {
        "binary" = {
          "path" = "__PROJECT_DIR__/.zed/lsp/dart";
        };
        "initialization_options" = {
          "onlyAnalyzeProjectsWithOpenFiles" = false;
          "suggestFromUnimportedLibraries" = true;
        };
      };
    };
  };
  zedFragmentJson = builtins.toJSON zedSettings;

in pkgs.mkShell {
  ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk";

  buildInputs = with pkgs; [
    dart
    flutter
    androidSdk
    jdk17
    gradle
    cmake
    ninja
    pkg-config
    sysprof
    clang
    chromium
    gtk3
    glib
    mesa-demos
    xorg.libX11
    xorg.libXcursor
    xorg.libXrandr
    xorg.libXi
    libxkbcommon
    libGL
    libglvnd
    wayland
    curl
    unzip
    zip
    which
  ] ++ extraPackages;

  shellHook = ''
    export TERM=xterm-256color
    ln -sfn "${pkgs.flutter}" .flutter-sdk

    # Set pkg-config paths for Linux desktop development
    export PKG_CONFIG_PATH="${pkgs.sysprof}/lib/pkgconfig:${pkgs.glib.dev}/lib/pkgconfig:${pkgs.gtk3}/lib/pkgconfig:${pkgs.xorg.libX11}/lib/pkgconfig"

    mkdir -p .vscode
    if [ ! -f .vscode/settings.json ] || [ "$(cat .vscode/settings.json 2>/dev/null)" != '${settingsJson}' ]; then
      echo '${settingsJson}' > .vscode/settings.json
    fi

    export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$PATH"
    export CHROME_EXECUTABLE=${pkgs.chromium}/bin/chromium

    flutter_dep_hash=""
    if [ -f "pubspec.yaml" ] || [ -f "pubspec.lock" ]; then
      flutter_dep_hash=$(cat pubspec.yaml pubspec.lock 2>/dev/null | sha256sum | cut -d' ' -f1)
    fi

    flutter_dep_stamp_file=".dart_tool/.deps.stamp"
    flutter_previous_dep_hash=""
    if [ -f "$flutter_dep_stamp_file" ]; then
      flutter_previous_dep_hash=$(cat "$flutter_dep_stamp_file")
    fi

    if [ -n "$flutter_dep_hash" ] && [ "$flutter_dep_hash" != "$flutter_previous_dep_hash" ]; then
      echo "📦 Flutter manifest changed. Running flutter pub get..."
      if flutter pub get; then
        mkdir -p .dart_tool
        echo "$flutter_dep_hash" > "$flutter_dep_stamp_file"
        # Run build_runner if freezed is in dependencies
        if grep -iq "freezed" pubspec.yaml; then
          echo "🔄 Freezed detected. Running build_runner..."
          flutter pub run build_runner build --delete-conflicting-outputs || true
        fi
      fi
    elif [ -n "$flutter_dep_hash" ]; then
      echo "✅ Flutter dependencies unchanged. Skipping pub get."
    fi

    flutter_license_stamp_file=".dart_tool/.android_licenses.stamp"
    if [ ! -f "$flutter_license_stamp_file" ]; then
      echo "📄 Attempting to accept Android SDK licenses..."

      # Method 1: Try sdkmanager directly (more reliable)
      if command -v sdkmanager >/dev/null 2>&1; then
        echo "Using sdkmanager to accept licenses..."
        if yes | sdkmanager --licenses >/dev/null 2>&1; then
          mkdir -p .dart_tool
          touch "$flutter_license_stamp_file"
          echo "✅ Android SDK licenses accepted via sdkmanager"
        else
          echo "⚠️ sdkmanager license acceptance failed, trying flutter doctor..."
        fi
      fi

      # Method 2: Fall back to flutter doctor
      if [ ! -f "$flutter_license_stamp_file" ]; then
        echo "Using flutter doctor to accept licenses..."
        if yes | flutter doctor --android-licenses >/dev/null 2>&1; then
          mkdir -p .dart_tool
          touch "$flutter_license_stamp_file"
          echo "✅ Android SDK licenses accepted via flutter doctor"
        else
          echo "⚠️ Could not automatically accept Android SDK licenses"
          echo "⚠️ You may need to run: flutter doctor --android-licenses"
          echo "⚠️ Or: sdkmanager --licenses"
        fi
      fi
    else
      echo "✅ Android SDK licenses already accepted"
    fi

    if [ -n "$PS1" ]; then
      echo "Flutter environment ready (${if withEmulator then "emulator" else "standard"})"
    fi

    # Setup Zed LSP wrapper for dart (NixOS compatible)
    mkdir -p .zed/lsp
    cat > .zed/lsp/dart << 'DART_WRAPPER'
#!/usr/bin/env bash
# Reusable dart wrapper for Zed on NixOS
# Uses the wrapper's own location to find the project root (two levels up from .zed/lsp/)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "''${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Use direnv to run dart analysis server with the correct environment
exec direnv exec "$PROJECT_DIR" dart "$@"
DART_WRAPPER
    chmod +x .zed/lsp/dart

    # Write Zed settings fragment for merging
    mkdir -p .zed/lsp-config
    echo '${zedFragmentJson}' > .zed/lsp-config/flutter.json

    # Merge all Zed settings fragments into .zed/settings.json
    if command -v node &>/dev/null; then
      node -e "
        const fs = require('fs');
        const path = require('path');
        const configDir = '.zed/lsp-config';
        const fragments = [];
        if (fs.existsSync(configDir)) {
          fs.readdirSync(configDir).forEach(f => {
            if (f.endsWith('.json')) {
              try {
                fragments.push(JSON.parse(fs.readFileSync(path.join(configDir, f), 'utf8')));
              } catch (e) {
                console.error('Failed to parse fragment:', f, e.message);
              }
            }
          });
        }
        function deepMerge(target, source) {
          const output = Object.assign({}, target);
          if (typeof target === 'object' && typeof source === 'object') {
            Object.keys(source).forEach(key => {
              if (typeof source[key] === 'object' && source[key] !== null && !Array.isArray(source[key])) {
                output[key] = deepMerge(target[key] || {}, source[key]);
              } else {
                output[key] = source[key];
              }
            });
          }
          return output;
        }
        const merged = fragments.reduce((acc, frag) => deepMerge(acc, frag), {});
        // Replace __PROJECT_DIR__ placeholder with actual project directory
        const projectDir = process.env.PWD || process.cwd();
        const settingsStr = JSON.stringify(merged, null, 2).replace(/__PROJECT_DIR__/g, projectDir);
        fs.writeFileSync('.zed/settings.json', settingsStr + '\n');
        console.log('✅ Zed settings merged from', fragments.length, 'fragment(s)');
      "
    else
      echo '${zedFragmentJson}' | sed "s|__PROJECT_DIR__|$PWD|g" > .zed/settings.json
      echo "⚠️  Node not available. Using Flutter Zed settings only."
    fi
  '';
  passthru = {
    inherit vscodeSettings zedSettings;
  };
}
