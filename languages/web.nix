{ pkgs, ... }:

{
  extraPackages ? [ ],
}:

let
  common = import ./common.nix { inherit pkgs; };

  # 定义在 packages/web-check.nix，从这里再引一次当默认值。
  web-check = import ../packages/web-check.nix { inherit pkgs; };
in
common.mkShell {
  buildInputs =
    with pkgs;
    [
      nodejs
      chromium
      web-check
    ]
    ++ extraPackages;

  shellHook = ''
    # check.sh 里的 Playwright 用例靠这个找浏览器，别在项目里再判一次路径
    export PLAYWRIGHT_CHROMIUM="${pkgs.chromium}/bin/chromium"

    echo "🌐 Web environment initialized"
  '';
}
