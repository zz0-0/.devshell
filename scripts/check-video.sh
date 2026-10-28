#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
system="${1:-x86_64-linux}"

nix eval --raw --impure --expr "
let
  flake = builtins.getFlake \"${root}\";
  video = flake.lib.${system}.video;
in
(video { }).drvPath
"
