{
  description = "Nix project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    devshell.url = "github:zz0-0/devshell";
  };

  outputs =
    { nixpkgs, devshell, ... }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      shell = devshell.lib.x86_64-linux.nix { };
    in
    {
      # Supported systems: x86_64-linux, aarch64-linux
      devShells.x86_64-linux.default = shell;
      # 第一天唯一真实的谓词：声明的环境能被构建
      checks.x86_64-linux.devshell = pkgs.runCommand "devshell-builds" { } ''
        echo ${shell} > $out
      '';
    };
}
