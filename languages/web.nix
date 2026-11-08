{ pkgs, ... }:

{
  extraPackages ? [ ],
}:

let
  common = import ./common.nix { inherit pkgs; };

  # 网页的机械错检查。跨项目、和语言无关，所以跟着环境走：
  # 只有声明 web 的项目才拿得到它。
  web-check = pkgs.writeShellApplication {
    name = "web-check";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      gnugrep
    ];
    text = builtins.readFile ./web-check.sh;
  };
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
