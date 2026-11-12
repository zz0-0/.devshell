{
  description = "Video production project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    devshell.url = "github:zz0-0/devshell";
  };

  outputs =
    { nixpkgs, devshell, ... }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      shell = devshell.lib.x86_64-linux.video { };
    in
    {
      devShells.x86_64-linux.default = shell;
      # 第一天唯一的谓词：声明的环境能被构建。
      # 注意：产物进 store 之后 nix flake check 会说 "0 flake checks / all checks passed"——
      # 那不是空集，是缓存。每次都要跑的真断言在 ./check.sh 的「工具」段。
      checks.x86_64-linux.devshell = pkgs.runCommand "devshell-builds" { } ''
        echo ${shell} > $out
      '';
    };
}
