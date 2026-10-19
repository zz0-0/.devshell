{ pkgs, ... }:

{
  extraPackages ? [ ],
}:

let
  common = import ./common.nix { inherit pkgs; };
in
common.mkShell {
  buildInputs =
    with pkgs;
    [
      ffmpeg
      mediainfo
      mkvtoolnix
      imagemagick
      exiftool
      sox
      librsvg
      potrace
      yt-dlp
      yq
      ripgrep
      fd
      hyperfine
      tree
      pv
      python3
      uv
      nodejs
      chromium
      whisper-cpp
      wf-recorder
      assimp
    ]
    ++ extraPackages;

  shellHook = ''
    export HYPERFRAMES_BROWSER_PATH="${pkgs.chromium}/bin/chromium"
    export REMOTION_BROWSER_EXECUTABLE="${pkgs.chromium}/bin/chromium"
    export PUPPETEER_EXECUTABLE_PATH="${pkgs.chromium}/bin/chromium"
    export CHROME_PATH="${pkgs.chromium}/bin/chromium"

    echo "🎬 Video production environment loaded"
  '';
}
