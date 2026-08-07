{ pkgs, ... }:

{
  extraPackages ? [ ],
  withEmulator ? false,
}:

let
  lib = pkgs.lib;

  common = import ./common.nix { inherit pkgs; };
  inherit (common)
    mkShell
    writeVscodeSettings
    writeZedFragment
    mergeZedSettings
    writeLspWrapper
    ;

  # Note: Requires config.android_sdk.accept_license = true; to be set in your
  # top-level nixpkgs configuration (e.g., in flake.nix or ~/.config/nixpkgs/config.nix)
  androidComposition = pkgs.androidenv.composeAndroidPackages {
    buildToolsVersions = [
      "36.0.0"
      "28.0.3"
    ];
    platformVersions = [
      "36"
      "28"
    ];
    abiVersions = [
      "armeabi-v7a"
      "arm64-v8a"
    ]
    ++ lib.optional withEmulator "x86_64";

    includeEmulator = withEmulator;
    includeSystemImages = withEmulator;
  };

  androidSdk = androidComposition.androidsdk;

  # Key the patched-SDK cache by the store hash so it is rebuilt automatically
  # when nixpkgs updates (no stale /tmp copy).
  flutterStoreHash = builtins.substring 11 32 "${pkgs.flutter}";
  patchedSdk = "/tmp/flutter-sdk-${flutterStoreHash}";

  vscodeSettings = {
    "dart.flutterSdkPath" = ".flutter-sdk";
    "dart.sdkPath" = ".flutter-sdk/bin/cache/dart-sdk";
    "flutter.sdkPath" = ".flutter-sdk";
  };
  settingsJson = builtins.toJSON vscodeSettings;

  # Zed LSP settings fragment
  zedSettings = {
    "languages" = {
      "Dart" = {
        "format_on_save" = "on";
        "language_servers" = [ "dart" ];
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

in
common.mkShell {
  ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk";

  buildInputs =
    with pkgs;
    [
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
    ]
    ++ extraPackages;

  shellHook = ''
    ${writeVscodeSettings settingsJson}
    ${writeZedFragment "flutter" zedFragmentJson}
    ${writeLspWrapper {
      name = "dart";
      command = "dart language-server";
    }}
    ${mergeZedSettings}

    export TERM=xterm-256color
    ln -sfn "${pkgs.flutter}" .flutter-sdk

    # NixOS: flutter_tester in the nix store lacks +x permission.
    # Create a writable SDK mirror with executable engine in /tmp (keyed by store hash).
    PATCHED_SDK="${patchedSdk}"
    if [ ! -d "$PATCHED_SDK" ]; then
      FLUTTER_ORIG="${pkgs.flutter}"
      mkdir -p "$PATCHED_SDK"
      for d in "$FLUTTER_ORIG"/*; do
        name=$(basename "$d")
        [ "$name" != "bin" ] && ln -sfn "$d" "$PATCHED_SDK/$name"
      done
      mkdir "$PATCHED_SDK/bin"
      for f in "$FLUTTER_ORIG/bin"/*; do
        name=$(basename "$f")
        [ "$name" != "cache" ] && ln -sfn "$f" "$PATCHED_SDK/bin/$name"
      done
      mkdir "$PATCHED_SDK/bin/cache"
      for f in "$FLUTTER_ORIG/bin/cache"/*; do
        name=$(basename "$f")
        [ "$name" != "artifacts" ] && ln -sfn "$f" "$PATCHED_SDK/bin/cache/$name"
      done
      mkdir -p "$PATCHED_SDK/bin/cache/artifacts/engine"
      for f in "$FLUTTER_ORIG/bin/cache/artifacts/engine"/*; do
        name=$(basename "$f")
        [ "$name" != "linux-x64" ] && ln -sfn "$f" "$PATCHED_SDK/bin/cache/artifacts/engine/$name"
      done
      mkdir -p "$PATCHED_SDK/bin/cache/artifacts/engine/linux-x64"
      cp "$FLUTTER_ORIG/bin/cache/artifacts/engine/linux-x64/"* \
        "$PATCHED_SDK/bin/cache/artifacts/engine/linux-x64/"
      chmod +x "$PATCHED_SDK/bin/cache/artifacts/engine/linux-x64/flutter_tester"
      echo "✅ Flutter engine patched for NixOS (cached at $PATCHED_SDK)"
    fi
    export FLUTTER_ROOT="$PATCHED_SDK"

    # Set pkg-config paths for Linux desktop development
    export PKG_CONFIG_PATH="${pkgs.sysprof}/lib/pkgconfig:${pkgs.glib.dev}/lib/pkgconfig:${pkgs.gtk3}/lib/pkgconfig:${pkgs.xorg.libX11}/lib/pkgconfig"

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
  '';
  passthru = {
    inherit vscodeSettings zedSettings;
  };
}
