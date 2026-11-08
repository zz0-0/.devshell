{ pkgs }:

# 网页的机械错。独立成一个包，而不是焊死在 web 模块里——
# Flutter 项目也可能有手写的静态页，它不该为了一个脚本把整个 web 工具链拖进来。
pkgs.writeShellApplication {
  name = "web-check";
  runtimeInputs = with pkgs; [
    coreutils
    findutils
    gnugrep
  ];
  text = builtins.readFile ../languages/web-check.sh;
}
